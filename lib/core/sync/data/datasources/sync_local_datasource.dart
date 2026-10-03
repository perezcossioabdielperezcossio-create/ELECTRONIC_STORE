import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sync_operation_model.dart';

import '../../../../features/inventory/data/models/lot_model.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueue(SyncOperationModel operation);
  Future<List<SyncOperationModel>> getPendingOperations();
  Future<void> markAsSynced(String id);
  Future<void> markAsFailed(String id, String error);
  Future<void> syncProducts(List<Map<String, dynamic>> products);
  Future<void> syncLots(List<Map<String, dynamic>> lots);
  Future<void> syncSales(List<Map<String, dynamic>> sales);
  Future<void> insertOrUpdateLot(LotModel lot);
  Future<void> deleteLot(String id);
}

class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final DatabaseHelper dbHelper;

  SyncLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<void> enqueue(SyncOperationModel operation) async {
    final db = await dbHelper.database;
    await db.insert('sync_queue', operation.toMap());
  }

  @override
  Future<List<SyncOperationModel>> getPendingOperations() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'sync_queue',
      where: "status = 'PENDING' OR status = 'FAILED'",
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => SyncOperationModel.fromMap(map)).toList();
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAsFailed(String id, String error) async {
    final db = await dbHelper.database;
    
    // Get current retry count
    final result = await db.query('sync_queue', columns: ['retry_count'], where: 'id = ?', whereArgs: [id]);
    int currentRetryCount = 0;
    if (result.isNotEmpty) {
      currentRetryCount = (result.first['retry_count'] as int?) ?? 0;
    }
    
    await db.update(
      'sync_queue',
      {
        'status': 'FAILED',
        'retry_count': currentRetryCount + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> insertOrUpdateLot(LotModel lot) async {
    final db = await dbHelper.database;
    final map = lot.toSqliteMap();
    
    // If product_id doesn't match an id in products, check if it matches a sku
    final prod = await db.query('products', where: 'id = ?', whereArgs: [lot.productId], limit: 1);
    if (prod.isEmpty) {
      final prodBySku = await db.query('products', where: 'sku = ?', whereArgs: [lot.productId], limit: 1);
      if (prodBySku.isNotEmpty) {
        map['product_id'] = prodBySku.first['id'];
      }
    }
    
    await db.insert(
      'lots',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteLot(String id) async {
    final db = await dbHelper.database;
    await db.delete('lots', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> syncProducts(List<Map<String, dynamic>> products) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (final rawProduct in products) {
        try {
          final productMap = Map<String, dynamic>.from(rawProduct);
          productMap.remove('clientTimestamp');
          productMap.remove('lastModified');
          productMap.remove('lots');

          final validCols = {
            'id', 'sku', 'name', 'brand', 'category', 
            'standard_selling_price', 'min_stock_threshold', 
            'is_active', 'created_at'
          };
          productMap.removeWhere((k, v) => !validCols.contains(k));

          if (productMap.containsKey('id') && productMap.containsKey('sku')) {
            await txn.insert(
              'products',
              productMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
  }

  @override
  Future<void> syncLots(List<Map<String, dynamic>> lots) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (final rawLot in lots) {
        try {
          final lotModel = LotModel.fromMap(rawLot);
          if (lotModel.id.isNotEmpty) {
            final map = lotModel.toSqliteMap();
            // Validate product_id / sku
            final prod = await txn.query('products', where: 'id = ?', whereArgs: [lotModel.productId], limit: 1);
            if (prod.isEmpty) {
              final prodBySku = await txn.query('products', where: 'sku = ?', whereArgs: [lotModel.productId], limit: 1);
              if (prodBySku.isNotEmpty) {
                map['product_id'] = prodBySku.first['id'];
              }
            }
            await txn.insert(
              'lots',
              map,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
  }

  @override
  Future<void> syncSales(List<Map<String, dynamic>> sales) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (final rawSale in sales) {
        try {
          final saleMap = Map<String, dynamic>.from(rawSale);
          final itemsList = saleMap.remove('items');
          saleMap.remove('clientTimestamp');
          saleMap.remove('lastModified');

          final validCols = {
            'id', 'created_at', 'payment_method', 'delivery_method', 
            'delivery_fee', 'discount', 'tax', 'total', 'status', 
            'customer_name', 'customer_phone', 'promoter_id', 'notes', 'is_locked'
          };
          saleMap.removeWhere((k, v) => !validCols.contains(k));

          if (saleMap.containsKey('id')) {
            await txn.insert(
              'sales',
              saleMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          if (itemsList is List) {
            for (final item in itemsList) {
              if (item is Map<String, dynamic>) {
                final itemMap = Map<String, dynamic>.from(item);
                final validItemCols = {
                  'id', 'sale_id', 'product_id', 'product_name', 
                  'quantity', 'unit_price', 'unit_cost', 'line_discount'
                };
                itemMap.removeWhere((k, v) => !validItemCols.contains(k));

                if (!itemMap.containsKey('id') || itemMap['id'] == null) {
                  itemMap['id'] = '${saleMap['id']}_${itemMap['product_id']}';
                }
                if (!itemMap.containsKey('sale_id') || itemMap['sale_id'] == null) {
                  itemMap['sale_id'] = saleMap['id'];
                }

                await txn.insert(
                  'sale_items',
                  itemMap,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
  }

}
