import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sync_operation_model.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueue(SyncOperationModel operation);
  Future<List<SyncOperationModel>> getPendingOperations();
  Future<void> markAsSynced(String id);
  Future<void> markAsFailed(String id, String error);
  Future<void> syncProducts(List<Map<String, dynamic>> products);
  Future<void> syncLots(List<Map<String, dynamic>> lots);
  Future<void> syncSales(List<Map<String, dynamic>> sales);
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
          final lotMap = Map<String, dynamic>.from(rawLot);
          lotMap.remove('clientTimestamp');
          lotMap.remove('lastModified');

          final validCols = {
            'id', 'product_id', 'purchase_date', 'initial_quantity', 
            'current_quantity', 'real_unit_cost', 'promoter_base_price', 'is_active'
          };
          lotMap.removeWhere((k, v) => !validCols.contains(k));

          if (lotMap.containsKey('id') && lotMap.containsKey('product_id')) {
            await txn.insert(
              'lots',
              lotMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else if (lotMap.containsKey('id') && lotMap.containsKey('current_quantity')) {
            await txn.update(
              'lots',
              {'current_quantity': lotMap['current_quantity']},
              where: 'id = ?',
              whereArgs: [lotMap['id']],
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
