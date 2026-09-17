import '../../../../data/local/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/product_model.dart';
import '../models/inventory_batch_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class InventoryLocalDatasource {
  Future<List<ProductModel>>        getAllProducts();
  Future<ProductModel>              getProductById(String id);
  Future<void>                      saveProduct(ProductModel model);
  Future<void>                      deleteProduct(String id);
  Future<List<InventoryBatchModel>> getBatchesForProduct(String productId);
  Future<void>                      addBatch(InventoryBatchModel model);
  Future<List<InventoryBatchModel>> consumeStock(String productId, int quantity);
}

class InventoryLocalDatasourceImpl implements InventoryLocalDatasource {
  final DatabaseHelper dbHelper;
  const InventoryLocalDatasourceImpl(this.dbHelper);

  @override
  Future<List<ProductModel>> getAllProducts() async {
    final db   = await dbHelper.database;
    final maps = await db.query('products', where: 'is_active = 1');
    return maps.map(ProductModel.fromMap).toList();
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    final db   = await dbHelper.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) throw const NotFoundException('Producto no encontrado');
    return ProductModel.fromMap(maps.first);
  }

  @override
  Future<void> saveProduct(ProductModel model) async {
    final db = await dbHelper.database;
    await db.insert('products', model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await dbHelper.database;
    await db.update('products', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<InventoryBatchModel>> getBatchesForProduct(String productId) async {
    final db   = await dbHelper.database;
    final maps = await db.query(
      'inventory_batches',
      where:   'product_id = ? AND quantity > 0',
      whereArgs: [productId],
      orderBy: 'received_at ASC', // FIFO
    );
    return maps.map(InventoryBatchModel.fromMap).toList();
  }

  @override
  Future<void> addBatch(InventoryBatchModel model) async {
    final db = await dbHelper.database;
    await db.insert('inventory_batches', model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<InventoryBatchModel>> consumeStock(
      String productId, int quantity) async {
    final db      = await dbHelper.database;
    final batches = await getBatchesForProduct(productId);
    final consumed = <InventoryBatchModel>[];
    var   remaining = quantity;

    for (final batch in batches) {
      if (remaining <= 0) break;
      final take = batch.quantity < remaining ? batch.quantity : remaining;
      await db.update(
        'inventory_batches',
        {'quantity': batch.quantity - take},
        where: 'id = ?', whereArgs: [batch.id],
      );
      consumed.add(batch);
      remaining -= take;
    }

    if (remaining > 0) throw const ValidationException('Stock insuficiente');
    return consumed;
  }
}
