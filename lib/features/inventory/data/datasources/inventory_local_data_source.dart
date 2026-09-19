import 'package:sqflite/sqflite.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';


abstract class InventoryLocalDataSource {
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot);
  Future<void> addLotToProduct(String productId, LotModel lot);
  Future<ProductModel?> getProductBySku(String sku);
  Future<List<ProductModel>> getActiveInventory();

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
    final result = await database.rawQuery('''
      SELECT p.*, COALESCE(SUM(r.quantity), 0) AS active_reserved_units
      FROM products p
      LEFT JOIN reservations r ON r.product_id = p.id AND r.status = 'ACTIVE'
      WHERE p.sku = ?
      GROUP BY p.id
    ''', [sku]);

    if (result.isEmpty) return null;

    final productMap = result.first;
    final productId = productMap['id'] as String;

    final lotsResult = await database.query(
      'lots',
      where: 'product_id = ? AND current_quantity > 0',
      whereArgs: [productId],
    );

    final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();

    return ProductModel.fromMap(productMap, lots);
  }

  @override
  Future<List<ProductModel>> getActiveInventory() async {
    final productsResult = await database.rawQuery('''
      SELECT p.*, COALESCE(SUM(r.quantity), 0) AS active_reserved_units
      FROM products p
      LEFT JOIN reservations r ON r.product_id = p.id AND r.status = 'ACTIVE'
      GROUP BY p.id
    ''');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0',
        whereArgs: [productId],
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots));
    }
    
    return inventory;
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    final productsResult = await database.rawQuery('''
      SELECT p.*, COALESCE(SUM(r.quantity), 0) AS active_reserved_units
      FROM products p
      LEFT JOIN reservations r ON r.product_id = p.id AND r.status = 'ACTIVE'
      WHERE p.is_active = 1
      GROUP BY p.id
    ''');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0',
        whereArgs: [productId],
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots));
    }

    return inventory;
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

    for (final lot in lots) {
      if (remaining <= 0) break;
      final take = lot.currentQuantity < remaining ? lot.currentQuantity : remaining;
      await database.update(
        'lots',
        {'current_quantity': lot.currentQuantity - take},
        where: 'id = ?', whereArgs: [lot.id],
      );
      consumed.add(lot);
      remaining -= take;
    }

    if (remaining > 0) throw Exception('Stock insuficiente');
    return consumed;
  }
}
