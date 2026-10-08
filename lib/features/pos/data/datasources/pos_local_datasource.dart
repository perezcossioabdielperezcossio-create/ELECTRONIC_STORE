import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sale_model.dart';
import '../models/sale_detail_model.dart';
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

  @override
  Future<void> saveSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      try {
        await txn.insert('sales', model.toSqliteSalesMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
      try {
        await txn.insert('ventas', model.toSqliteVentasMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}

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

        final lotsMaps = await txn.query(
          'lots',
          where: 'product_id = ? AND current_quantity > 0',
          whereArgs: [item.productId],
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
      try {
        await txn.insert('sales', model.toSqliteSalesMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
      try {
        await txn.insert('ventas', model.toSqliteVentasMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}

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
        status: model.status,
        promoterId: model.promoterId,
        notes: model.notes,
        paymentMethod: model.paymentMethod,
        deliveryMethod: model.deliveryMethod,
        deliveryFee: model.deliveryFee,
        customerName: model.customerName,
        customerPhone: model.customerPhone,
        isLocked: model.isLocked,
      );

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'sales',
        'operation': 'CREATE',
        'payload': jsonEncode(fullSale.toMap()),
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
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    List<Map<String, dynamic>> maps = [];
    try {
      maps = await db.query(
        'ventas',
        where: 'fecha_venta >= ? AND fecha_venta < ?',
        whereArgs: [startStr, endStr],
        orderBy: 'fecha_venta DESC',
      );
    } catch (_) {}

    if (maps.isEmpty) {
      try {
        maps = await db.query(
          'sales',
          where: 'created_at >= ? AND created_at < ?',
          whereArgs: [startStr, endStr],
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
