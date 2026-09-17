import 'package:sqflite/sqflite.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';
import '../models/inventory_batch_model.dart';

abstract class InventoryLocalDataSource {
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot);
  Future<void> addLotToProduct(String productId, LotModel lot);
  Future<ProductModel?> getProductBySku(String sku);
  Future<List<ProductModel>> getActiveInventory();

  Future<void> addBatch(InventoryBatchModel batch);
  Future<List<InventoryBatchModel>> consumeStock(String productId, int quantity);
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
      await txn.insert(
        'lots',
        initialLot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    });
  }

  @override
  Future<void> addLotToProduct(String productId, LotModel lot) async {
    await database.insert(
      'lots',
      lot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final maps = await database.query('products', where: 'is_active = 1');
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override
  Future<void> addBatch(InventoryBatchModel model) async {
    await database.insert('inventory_batches', model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<InventoryBatchModel>> consumeStock(String productId, int quantity) async {
    final maps = await database.query(
      'inventory_batches',
      where: 'product_id = ? AND quantity > 0',
      whereArgs: [productId],
      orderBy: 'received_at ASC',
    );
    final batches = maps.map((m) => InventoryBatchModel.fromMap(m)).toList();
    final consumed = <InventoryBatchModel>[];
    var remaining = quantity;

    for (final batch in batches) {
      if (remaining <= 0) break;
      final take = batch.quantity < remaining ? batch.quantity : remaining;
      await database.update(
        'inventory_batches',
        {'quantity': batch.quantity - take},
        where: 'id = ?', whereArgs: [batch.id],
      );
      consumed.add(batch);
      remaining -= take;
    }

    if (remaining > 0) throw Exception('Stock insuficiente');
    return consumed;
  }
}
