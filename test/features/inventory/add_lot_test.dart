import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/models/lot_model.dart';
import 'package:electronic_store/features/inventory/data/models/product_model.dart';
import 'dart:io';

void main() {
  late Database db;
  late InventoryLocalDataSourceImpl datasource;

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    
    // Create schema
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        sku TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        category TEXT NOT NULL,
        standard_selling_price REAL NOT NULL,
        min_stock_threshold INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE lots (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        purchase_date TEXT NOT NULL,
        initial_quantity INTEGER NOT NULL,
        current_quantity INTEGER NOT NULL,
        real_unit_cost REAL NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    datasource = InventoryLocalDataSourceImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addLotToProduct correctly adds a lot and increments available stock without altering previous lots', () async {
    // 1. Arrange: Create product with initial lot
    final product = const ProductModel(
      id: 'p1',
      sku: 'SKU1',
      name: 'Test Product',
      brand: 'Brand',
      category: 'Cat',
      standardSellingPrice: 100.0,
      minStockThreshold: 10,
    );

    final initialLot = LotModel(
      id: 'l1',
      productId: 'p1',
      purchaseDate: DateTime.now().subtract(const Duration(days: 10)),
      initialQuantity: 50,
      currentQuantity: 20, // 30 consumed
      realUnitCost: 40.0,
    );

    await datasource.saveProductWithInitialLot(product, initialLot);

    // 2. Act: Add a new lot
    final newLot = LotModel(
      id: 'l2',
      productId: 'p1',
      purchaseDate: DateTime.now(),
      initialQuantity: 100,
      currentQuantity: 100,
      realUnitCost: 45.0, // Different cost
    );

    await datasource.addLotToProduct('p1', newLot);

    // 3. Assert: Retrieve all products and check
    final products = await datasource.getAllProducts();
    expect(products.length, 1);
    
    final savedProduct = products.first;
    expect(savedProduct.id, 'p1');
    expect(savedProduct.lots.length, 2);

    // Sort lots to be deterministic
    savedProduct.lots.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    
    final lot1 = savedProduct.lots[0];
    final lot2 = savedProduct.lots[1];

    expect(lot1.id, 'l1');
    expect(lot1.realUnitCost, 40.0);
    expect(lot1.currentQuantity, 20);

    expect(lot2.id, 'l2');
    expect(lot2.realUnitCost, 45.0);
    expect(lot2.currentQuantity, 100);

    // Verify stock
    expect(savedProduct.availableStock, 120); // 20 + 100
  });
}
