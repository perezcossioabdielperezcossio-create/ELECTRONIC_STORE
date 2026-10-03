import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';


abstract class InventoryLocalDataSource {
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot);
  Future<void> addLotToProduct(String productId, LotModel lot);
  Future<ProductModel?> getProductBySku(String sku);
  Future<List<ProductModel>> getActiveInventory();

  Future<void> updateProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<List<LotModel>> consumeStock(String productId, int quantity);
  Future<List<ProductModel>> getAllProducts();
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  final Database database;

  InventoryLocalDataSourceImpl(this.database);

  @override
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot) async {
    await database.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'operation': 'CREATE',
        'payload': jsonEncode(product.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });

      final lotPayload = {
        'id': initialLot.id,
        'product_id': product.id,
        'productSku': product.sku,
        'productId': product.id,
        'costo_unitario_real': initialLot.realUnitCost,
        'real_unit_cost': initialLot.realUnitCost,
        'cantidad_actual': initialLot.currentQuantity,
        'current_quantity': initialLot.currentQuantity,
        'cantidad_inicial': initialLot.initialQuantity,
        'initial_quantity': initialLot.initialQuantity,
        'fecha_ingreso': initialLot.purchaseDate.toIso8601String(),
        'purchase_date': initialLot.purchaseDate.toIso8601String(),
        if (initialLot.promoterBasePrice != null) 'promoter_base_price': initialLot.promoterBasePrice,
        if (initialLot.promoterBasePrice != null) 'promoterBasePrice': initialLot.promoterBasePrice,
        'is_active': initialLot.isActive ? 1 : 0,
      };

      await txn.insert(
        'lots',
        initialLot.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'CREATE',
        'payload': jsonEncode(lotPayload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> addLotToProduct(String productId, LotModel lot) async {
    await database.transaction((txn) async {
      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;

      final lotPayload = {
        'id': lot.id,
        'product_id': productId,
        'productSku': sku,
        'productId': productId,
        'costo_unitario_real': lot.realUnitCost,
        'real_unit_cost': lot.realUnitCost,
        'cantidad_actual': lot.currentQuantity,
        'current_quantity': lot.currentQuantity,
        'cantidad_inicial': lot.initialQuantity,
        'initial_quantity': lot.initialQuantity,
        'fecha_ingreso': lot.purchaseDate.toIso8601String(),
        'purchase_date': lot.purchaseDate.toIso8601String(),
        if (lot.promoterBasePrice != null) 'promoter_base_price': lot.promoterBasePrice,
        if (lot.promoterBasePrice != null) 'promoterBasePrice': lot.promoterBasePrice,
        'is_active': lot.isActive ? 1 : 0,
      };

      await txn.insert(
        'lots',
        lot.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'CREATE',
        'payload': jsonEncode(lotPayload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<ProductModel?> getProductBySku(String sku) async {
    final result = await database.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final productMap = result.first;
    final productId = productMap['id'] as String;

    final lotsResult = await database.query(
      'lots',
      where: 'product_id = ? AND current_quantity > 0',
      whereArgs: [productId],
    );

    final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();

    return ProductModel.fromMap(productMap, lots: lots);
  }

  @override
  Future<List<ProductModel>> getActiveInventory() async {
    final productsResult = await database.query('products');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0',
        whereArgs: [productId],
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots: lots));
    }
    
    return inventory;
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    final productsResult = await database.query('products', where: 'is_active = 1');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0',
        whereArgs: [productId],
        orderBy: 'purchase_date ASC',
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots: lots));
    }
    
    return inventory;
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    await database.transaction((txn) async {
      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'operation': 'UPDATE',
        'payload': jsonEncode(product.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await database.transaction((txn) async {
      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;

      // Borrado en cascada (producto + lotes) con encolado en sync_queue
      final lots = await txn.query('lots', where: 'product_id = ?', whereArgs: [productId]);
      for (final lot in lots) {
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'DELETE',
          'payload': jsonEncode({'id': lot['id'], 'productSku': sku}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });
      }
      await txn.delete('lots', where: 'product_id = ?', whereArgs: [productId]);
      await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
      
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'operation': 'DELETE',
        'payload': jsonEncode({'id': productId, 'sku': sku}),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<List<LotModel>> consumeStock(String productId, int quantity) async {
    final maps = await database.query(
      'lots',
      where: 'product_id = ? AND current_quantity > 0',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC',
    );
    final lots = maps.map((m) => LotModel.fromMap(m)).toList();
    final consumed = <LotModel>[];
    var remaining = quantity;

    await database.transaction((txn) async {
      for (final lot in lots) {
        if (remaining <= 0) break;
        final take = lot.currentQuantity < remaining ? lot.currentQuantity : remaining;
        
        await txn.update(
          'lots',
          {'current_quantity': lot.currentQuantity - take},
          where: 'id = ?', whereArgs: [lot.id],
        );
        
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'UPDATE',
          'payload': jsonEncode({'id': lot.id, 'current_quantity': lot.currentQuantity - take}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });

        consumed.add(lot);
        remaining -= take;
      }
    });

    if (remaining > 0) throw Exception('Stock insuficiente');
    return consumed;
  }
}

