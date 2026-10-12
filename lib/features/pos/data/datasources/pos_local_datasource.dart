import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sale_model.dart';
import '../models/sale_detail_model.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_detail.dart';
import '../../../../core/errors/exceptions.dart';

abstract class PosLocalDatasource {
  Future<void> saveSale(SaleModel model);
  Future<void> processSale(SaleModel model);
  Future<SaleModel> getSaleById(String id);
  Future<List<SaleModel>> getSalesByDate(DateTime date);
  Future<void> voidSale(String id);
}

class PosLocalDatasourceImpl implements PosLocalDatasource {
  final DatabaseHelper dbHelper;
  const PosLocalDatasourceImpl(this.dbHelper);

  Future<void> _safeInsert(DatabaseExecutor txn, String table, Map<String, dynamic> map) async {
    try {
      await txn.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      try {
        final tableInfo = await txn.rawQuery("PRAGMA table_info($table)");
        final validCols = tableInfo.map((r) => r['name'] as String).toSet();
        if (validCols.isNotEmpty) {
          final filteredMap = Map<String, dynamic>.fromEntries(
            map.entries.where((e) => validCols.contains(e.key)),
          );
          await txn.insert(table, filteredMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> saveSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await _safeInsert(txn, 'sales', model.toSqliteSalesMap());
      await _safeInsert(txn, 'ventas', model.toSqliteVentasMap());

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'sales',
        'operation': 'CREATE',
        'payload': jsonEncode(model.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> processSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      final saleDetails = <SaleDetailModel>[];
      final processedItems = <SaleItem>[];

      for (final item in model.items) {
        int remainingQuantity = item.quantity;
        final netUnitPrice = item.quantity > 0 ? (item.unitPrice - (item.lineDiscount / item.quantity)) : 0.0;
        double totalItemCost = 0.0;

        String whereClause = 'product_id = ? AND current_quantity > 0 AND is_active = 1';
        final whereArgs = <dynamic>[item.productId];

        final locUpper = (model.origenVenta.isNotEmpty ? model.origenVenta : model.storeLocation).toUpperCase().trim();
        if (locUpper == 'TIENDA') {
          whereClause += " AND UPPER(COALESCE(location, 'ALMACEN')) = 'TIENDA'";
        } else {
          whereClause += " AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'";
        }

        final lotsMaps = await txn.query(
          'lots',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'purchase_date ASC',
        );

        for (final lot in lotsMaps) {
          if (remainingQuantity <= 0) break;

          final lotId = lot['id'] as String;
          final currentQuantity = lot['current_quantity'] as int;
          final realUnitCost = (lot['real_unit_cost'] as num).toDouble();

          if (netUnitPrice < realUnitCost) {
            throw AntiLossException('La venta del producto ${item.productName} generaría pérdida frente al costo del lote.');
          }

          final qtyToConsume = remainingQuantity <= currentQuantity ? remainingQuantity : currentQuantity;
          totalItemCost += qtyToConsume * realUnitCost;
          
          final newLotQty = currentQuantity - qtyToConsume;
          await txn.update(
            'lots',
            {'current_quantity': newLotQty},
            where: 'id = ?',
            whereArgs: [lotId],
          );

          await txn.insert('sync_queue', {
            'id': const Uuid().v4(),
            'table_name': 'lots',
            'operation': 'UPDATE',
            'payload': jsonEncode({'id': lotId, 'current_quantity': newLotQty}),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'PENDING',
            'retry_count': 0,
          });

          final detail = SaleDetailModel(
            id: const Uuid().v4(),
            ventaId: model.id,
            loteId: lotId,
            productId: item.productId,
            productName: item.productName,
            cantidad: qtyToConsume,
            costoUnitarioCompra: realUnitCost,
            precioUnitarioCobrado: netUnitPrice,
            lineDiscount: (item.lineDiscount / item.quantity) * qtyToConsume,
          );
          saleDetails.add(detail);

          try {
            await txn.insert('detalle_ventas', detail.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}

          remainingQuantity -= qtyToConsume;
        }

        if (remainingQuantity > 0) {
          throw InsufficientStockException('Stock insuficiente para el producto ${item.productName}.');
        }

        final averageUnitCost = item.quantity > 0 ? (totalItemCost / item.quantity) : 0.0;

        final processedItem = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          unitCost: averageUnitCost,
          lineDiscount: item.lineDiscount,
        );
        processedItems.add(processedItem);

        final itemMap = {
          'id': '${model.id}_${item.productId}',
          'sale_id': model.id,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': averageUnitCost,
          'line_discount': item.lineDiscount,
        };

        try {
          await txn.insert('sale_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}

        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'sale_items',
          'operation': 'CREATE',
          'payload': jsonEncode(itemMap),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });
      }

      // Save sale in sales & ventas
      final salesMap = Map<String, dynamic>.from(model.toSqliteSalesMap());
      salesMap['status'] = 'COMPLETED';
      salesMap['is_locked'] = 1;

      final ventasMap = Map<String, dynamic>.from(model.toSqliteVentasMap());
      ventasMap['status'] = 'COMPLETED';
      ventasMap['is_locked'] = 1;

      await _safeInsert(txn, 'sales', salesMap);
      await _safeInsert(txn, 'ventas', ventasMap);

      final fullSale = SaleModel(
        id: model.id,
        clienteId: model.clienteId,
        deliveryId: model.deliveryId,
        deliveryName: model.deliveryName,
        items: processedItems,
        details: saleDetails,
        createdAt: model.createdAt,
        discount: model.discount,
        tax: model.tax,
        status: SaleStatus.completed,
        promoterId: model.promoterId,
        notes: model.notes,
        paymentMethod: model.paymentMethod,
        deliveryMethod: model.deliveryMethod,
        deliveryFee: model.deliveryFee,
        customerName: model.customerName,
        customerPhone: model.customerPhone,
        isLocked: true,
        storeLocation: model.storeLocation,
        usuarioId: model.usuarioId,
      );

      final payloadMap = fullSale.toMap();
      payloadMap['status'] = 'COMPLETED';
      payloadMap['is_locked'] = true;

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'sales',
        'operation': 'CREATE',
        'payload': jsonEncode(payloadMap),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<SaleModel> getSaleById(String id) async {
    final db = await dbHelper.database;
    List<Map<String, dynamic>> maps = [];
    try {
      maps = await db.query('ventas', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
    if (maps.isEmpty) {
      maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    }
    if (maps.isEmpty) {
      throw Exception('Sale not found: $id');
    }

    final details = <SaleDetail>[];
    try {
      final detailsMaps = await db.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [id]);
      for (final dm in detailsMaps) {
        details.add(SaleDetailModel.fromMap(dm));
      }
    } catch (_) {}

    final items = <SaleItem>[];
    try {
      final itemsMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [id]);
      for (final im in itemsMaps) {
        items.add(SaleItem(
          productId: im['product_id'] as String,
          productName: im['product_name'] as String,
          quantity: (im['quantity'] as num).toInt(),
          unitPrice: (im['unit_price'] as num).toDouble(),
          unitCost: (im['unit_cost'] as num?)?.toDouble() ?? 0.0,
          lineDiscount: (im['line_discount'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    } catch (_) {}

    return SaleModel.fromMap(maps.first, items: items, details: details);
  }

  @override
  Future<List<SaleModel>> getSalesByDate(DateTime date) async {
    final db = await dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    const dateWhere = "(substr(COALESCE(fecha_venta, created_at), 1, 10) = ? OR date(COALESCE(fecha_venta, created_at)) = date(?)) AND (UPPER(COALESCE(status, 'COMPLETED')) != 'VOIDED' AND UPPER(COALESCE(status, 'COMPLETED')) != 'ANULADA')";

    List<Map<String, dynamic>> maps = [];
    try {
      maps = await db.query(
        'ventas',
        where: dateWhere,
        whereArgs: [dateStr, dateStr],
        orderBy: 'fecha_venta DESC',
      );
    } catch (_) {}

    if (maps.isEmpty) {
      try {
        maps = await db.query(
          'sales',
          where: dateWhere,
          whereArgs: [dateStr, dateStr],
          orderBy: 'created_at DESC',
        );
      } catch (_) {}
    }

    final sales = <SaleModel>[];
    for (final m in maps) {
      final saleId = m['id'] as String;

      final details = <SaleDetail>[];
      try {
        final detailsMaps = await db.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [saleId]);
        for (final dm in detailsMaps) {
          details.add(SaleDetailModel.fromMap(dm));
        }
      } catch (_) {}

      final items = <SaleItem>[];
      try {
        final itemsMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final im in itemsMaps) {
          items.add(SaleItem(
            productId: im['product_id'] as String,
            productName: im['product_name'] as String,
            quantity: (im['quantity'] as num).toInt(),
            unitPrice: (im['unit_price'] as num).toDouble(),
            unitCost: (im['unit_cost'] as num?)?.toDouble() ?? 0.0,
            lineDiscount: (im['line_discount'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      } catch (_) {}

      sales.add(SaleModel.fromMap(m, items: items, details: details));
    }
    return sales;
  }

  @override
  Future<void> voidSale(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      try {
        await txn.update('sales', {'status': 'voided'}, where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
      try {
        await txn.update('ventas', {'status': 'voided'}, where: 'id = ?', whereArgs: [id]);
      } catch (_) {}

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'sales',
        'operation': 'UPDATE',
        'payload': jsonEncode({'id': id, 'status': 'voided'}),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }
}
