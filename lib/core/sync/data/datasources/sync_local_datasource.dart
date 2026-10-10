import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/sync_operation_model.dart';
import '../../../../features/inventory/data/models/lot_model.dart';
import '../../../../features/clients/data/models/client_model.dart';
import '../../../../features/deliveries/data/models/delivery_model.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueue(SyncOperationModel operation);
  Future<List<SyncOperationModel>> getPendingOperations();
  Future<void> markAsSynced(String id);
  Future<void> markAsFailed(String id, String error);
  Future<void> syncProducts(List<Map<String, dynamic>> products);
  Future<void> syncLots(List<Map<String, dynamic>> lots);
  Future<void> syncSales(List<Map<String, dynamic>> sales);
  Future<void> syncClients(List<Map<String, dynamic>> clients);
  Future<void> syncDeliveries(List<Map<String, dynamic>> deliveries);
  Future<void> insertOrUpdateLot(LotModel lot);
  Future<void> deleteLot(String id);
  Future<void> insertOrUpdateClient(ClientModel client);
  Future<void> deleteClient(String id);
  Future<List<ClientModel>> getClients();
  Future<void> insertOrUpdateDelivery(DeliveryModel delivery);
  Future<void> deleteDelivery(String id);
  Future<List<DeliveryModel>> getDeliveries();
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
  Future<void> insertOrUpdateDelivery(DeliveryModel delivery) async {
    final db = await dbHelper.database;
    try {
      await db.insert(
        'deliveries',
        delivery.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteDelivery(String id) async {
    final db = await dbHelper.database;
    try {
      await db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  @override
  Future<List<DeliveryModel>> getDeliveries() async {
    final db = await dbHelper.database;
    try {
      final results = await db.query('deliveries', orderBy: 'nombre ASC');
      return results.map((m) => DeliveryModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> syncDeliveries(List<Map<String, dynamic>> deliveries) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (final rawDelivery in deliveries) {
        try {
          final deliveryModel = DeliveryModel.fromMap(rawDelivery);
          if (deliveryModel.id.isNotEmpty) {
            try {
              await txn.insert(
                'deliveries',
                deliveryModel.toSqliteMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
  }

  @override
  Future<void> insertOrUpdateClient(ClientModel client) async {
    final db = await dbHelper.database;
    try {
      await db.insert(
        'clientes',
        client.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
    try {
      await db.insert(
        'customers',
        client.toSqliteCustomerMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteClient(String id) async {
    final db = await dbHelper.database;
    try {
      await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
    try {
      await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  @override
  Future<List<ClientModel>> getClients() async {
    final db = await dbHelper.database;
    try {
      final results = await db.query('clientes', orderBy: 'creado_en DESC');
      if (results.isNotEmpty) {
        return results.map((m) => ClientModel.fromMap(m)).toList();
      }
    } catch (_) {}
    try {
      final results = await db.query('customers', orderBy: 'created_at DESC');
      return results.map((m) => ClientModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> syncClients(List<Map<String, dynamic>> clients) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (final rawClient in clients) {
        try {
          final clientModel = ClientModel.fromMap(rawClient);
          if (clientModel.id.isNotEmpty) {
            try {
              await txn.insert(
                'clientes',
                clientModel.toSqliteMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
            try {
              await txn.insert(
                'customers',
                clientModel.toSqliteCustomerMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
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
          final detailsList = saleMap.remove('sale_details');
          saleMap.remove('clientTimestamp');
          saleMap.remove('lastModified');

          final validSalesCols = {
            'id', 'cliente_id', 'delivery_id', 'delivery_name', 'total_cobrado', 'metodo_pago', 'tipo_entrega', 
            'fecha_venta', 'created_at', 'payment_method', 'delivery_method', 
            'delivery_fee', 'discount', 'tax', 'total', 'status', 
            'customer_name', 'customer_phone', 'promoter_id', 'notes', 'is_locked'
          };
          saleMap.removeWhere((k, v) => !validSalesCols.contains(k));

          // Ensure basic fields
          saleMap['total'] ??= saleMap['total_cobrado'];
          saleMap['total_cobrado'] ??= saleMap['total'];
          saleMap['payment_method'] ??= saleMap['metodo_pago'] ?? 'EFECTIVO';
          saleMap['metodo_pago'] ??= saleMap['payment_method'];
          saleMap['delivery_method'] ??= saleMap['tipo_entrega'] ?? 'TIENDA';
          saleMap['tipo_entrega'] ??= saleMap['delivery_method'];
          saleMap['created_at'] ??= saleMap['fecha_venta'] ?? DateTime.now().toIso8601String();
          saleMap['fecha_venta'] ??= saleMap['created_at'];

          if (saleMap.containsKey('id')) {
            try {
              await txn.insert(
                'sales',
                saleMap,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
            try {
              await txn.insert(
                'ventas',
                saleMap,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
          }

          // Process sale details / items
          final combinedList = (detailsList is List ? detailsList : (itemsList is List ? itemsList : []));
          for (final item in combinedList) {
            if (item is Map<String, dynamic>) {
              final itemMap = Map<String, dynamic>.from(item);
              final id = itemMap['id'] ?? '${saleMap['id']}_${itemMap['product_id'] ?? itemMap['lote_id']}';
              final saleId = itemMap['venta_id'] ?? itemMap['sale_id'] ?? saleMap['id'];
              final lotId = itemMap['lote_id'] ?? itemMap['lot_id'];
              final prodId = itemMap['product_id'] ?? '';
              final prodName = itemMap['product_name'] ?? '';
              final qty = (itemMap['cantidad'] as num?)?.toInt() ?? (itemMap['quantity'] as num?)?.toInt() ?? 1;
              final unitPrice = (itemMap['precio_unitario_cobrado'] as num?)?.toDouble() ?? (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0;
              final unitCost = (itemMap['costo_unitario_compra'] as num?)?.toDouble() ?? (itemMap['unit_cost'] as num?)?.toDouble() ?? 0.0;
              final lineDiscount = (itemMap['line_discount'] as num?)?.toDouble() ?? 0.0;

              // Insert to detalle_ventas
              try {
                await txn.insert(
                  'detalle_ventas',
                  {
                    'id': id,
                    'venta_id': saleId,
                    'lote_id': lotId,
                    'product_id': prodId,
                    'product_name': prodName,
                    'cantidad': qty,
                    'costo_unitario_compra': unitCost,
                    'precio_unitario_cobrado': unitPrice,
                    'line_discount': lineDiscount,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              } catch (_) {}

              // Insert to sale_items
              try {
                await txn.insert(
                  'sale_items',
                  {
                    'id': id,
                    'sale_id': saleId,
                    'lote_id': lotId,
                    'product_id': prodId,
                    'product_name': prodName,
                    'quantity': qty,
                    'unit_price': unitPrice,
                    'unit_cost': unitCost,
                    'line_discount': lineDiscount,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              } catch (_) {}
            }
          }
        } catch (_) {
          // ignore mapping errors for incomplete remote docs
        }
      }
    });
  }
}
