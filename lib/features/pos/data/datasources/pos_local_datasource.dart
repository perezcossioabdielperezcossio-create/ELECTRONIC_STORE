import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sale_model.dart';
import '../../domain/entities/sale_item.dart';
import '../../../../core/errors/exceptions.dart';

abstract class PosLocalDatasource {
  Future<void>          saveSale(SaleModel model);
  Future<void>          processSale(SaleModel model);
  Future<SaleModel>     getSaleById(String id);
  Future<List<SaleModel>> getSalesByDate(DateTime date);
  Future<void>          voidSale(String id);
}

class PosLocalDatasourceImpl implements PosLocalDatasource {
  final DatabaseHelper dbHelper;
  const PosLocalDatasourceImpl(this.dbHelper);

  @override
  Future<void> saveSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('sales', model.toMap());
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
      final saleMap = model.toMap();
      final itemsPayload = model.items.map((i) => {
        'id': '${model.id}_${i.productId}',
        'sale_id': model.id,
        'product_id': i.productId,
        'product_name': i.productName,
        'quantity': i.quantity,
        'unit_price': i.unitPrice,
        'unit_cost': i.unitCost,
        'line_discount': i.lineDiscount,
      }).toList();
      saleMap['items'] = itemsPayload;

      await txn.insert('sales', model.toMap());
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'sales',
        'operation': 'CREATE',
        'payload': jsonEncode(saleMap),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
      
      for (final item in model.items) {
        int remainingQuantity = item.quantity;
        final netUnitPrice = item.quantity > 0 ? (item.unitPrice - (item.lineDiscount / item.quantity)) : 0.0;
        double totalCost = 0.0;

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
          totalCost += qtyToConsume * realUnitCost;
          
          await txn.update(
            'lots',
            {'current_quantity': currentQuantity - qtyToConsume},
            where: 'id = ?',
            whereArgs: [lotId],
          );

          await txn.insert('sync_queue', {
            'id': const Uuid().v4(),
            'table_name': 'lots',
            'operation': 'UPDATE',
            'payload': jsonEncode({'id': lotId, 'current_quantity': currentQuantity - qtyToConsume}),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'PENDING',
            'retry_count': 0,
          });

          remainingQuantity -= qtyToConsume;
        }

        if (remainingQuantity > 0) {
          throw InsufficientStockException('Stock insuficiente para el producto ${item.productName}.');
        }

        final averageUnitCost = item.quantity > 0 ? (totalCost / item.quantity) : 0.0;

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

        await txn.insert('sale_items', itemMap);
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
    });
  }

  @override
  Future<SaleModel> getSaleById(String id) async {
    final db   = await dbHelper.database;
    final maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) {
      throw Exception('Sale not found: $id');
    }
    final itemsMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [id]);
    final items = itemsMaps.map((im) => SaleItem(
      productId: im['product_id'] as String,
      productName: im['product_name'] as String,
      quantity: im['quantity'] as int,
      unitPrice: (im['unit_price'] as num).toDouble(),
      unitCost: (im['unit_cost'] as num?)?.toDouble() ?? 0.0,
      lineDiscount: (im['line_discount'] as num?)?.toDouble() ?? 0.0,
    )).toList();
    return SaleModel.fromMap(maps.first, items: items);
  }

  @override
  Future<List<SaleModel>> getSalesByDate(DateTime date) async {
    final db    = await dbHelper.database;
    final start = DateTime(date.year, date.month, date.day);
    final end   = start.add(const Duration(days: 1));
    final maps  = await db.query(
      'sales',
      where:     'created_at >= ? AND created_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy:   'created_at DESC',
    );
    final sales = <SaleModel>[];
    for (final m in maps) {
      final saleId = m['id'] as String;
      final itemsMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      final items = itemsMaps.map((im) => SaleItem(
        productId: im['product_id'] as String,
        productName: im['product_name'] as String,
        quantity: im['quantity'] as int,
        unitPrice: (im['unit_price'] as num).toDouble(),
        unitCost: (im['unit_cost'] as num?)?.toDouble() ?? 0.0,
        lineDiscount: (im['line_discount'] as num?)?.toDouble() ?? 0.0,
      )).toList();
      sales.add(SaleModel.fromMap(m, items: items));
    }
    return sales;
  }

  @override
  Future<void> voidSale(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('sales', {'status': 'voided'},
          where: 'id = ?', whereArgs: [id]);
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
