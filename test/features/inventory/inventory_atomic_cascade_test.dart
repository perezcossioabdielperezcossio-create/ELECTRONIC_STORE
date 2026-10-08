import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/models/product_model.dart';
import 'package:electronic_store/features/inventory/data/models/lot_model.dart';

void main() {
  late Database db;
  late InventoryLocalDataSourceImpl dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              sku TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              brand TEXT,
              category TEXT,
              standard_selling_price REAL NOT NULL,
              min_stock_threshold INTEGER DEFAULT 5,
              is_active INTEGER DEFAULT 1,
              created_at TEXT DEFAULT (datetime('now'))
            );
          ''');
          await db.execute('''
            CREATE TABLE lots (
              id TEXT PRIMARY KEY,
              product_id TEXT NOT NULL,
              purchase_date TEXT NOT NULL,
              initial_quantity INTEGER NOT NULL,
              current_quantity INTEGER NOT NULL,
              real_unit_cost REAL NOT NULL,
              promoter_base_price REAL,
              location TEXT NOT NULL DEFAULT 'ALMACEN',
              is_active INTEGER DEFAULT 1,
              FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
            );
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              table_name TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              status TEXT DEFAULT 'PENDING',
              retry_count INTEGER DEFAULT 0
            );
          ''');
        },
      ),
    );

    dataSource = InventoryLocalDataSourceImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Inventory Atomic Insertion, Reactive Stock & Cascade Delete', () {
    test('saveProductWithInitialLot inserts product and lot in transaction and enqueues to sync_queue', () async {
      final product = ProductModel(
        id: 'prod_1',
        sku: 'SKU-001',
        name: 'Smartphone Pro',
        brand: 'Samsung',
        category: 'Móviles',
        standardSellingPrice: 450.0,
        minStockThreshold: 3,
      );

      final lot = LotModel(
        id: 'lot_1',
        productId: 'prod_1',
        purchaseDate: DateTime.parse('2026-01-10T10:00:00Z'),
        initialQuantity: 15,
        currentQuantity: 15,
        realUnitCost: 300.0,
      );

      await dataSource.saveProductWithInitialLot(product, lot);

      // Verify product exists in SQLite
      final productsInDb = await db.query('products', where: 'id = ?', whereArgs: ['prod_1']);
      expect(productsInDb.length, 1);
      expect(productsInDb.first['name'], 'Smartphone Pro');

      // Verify lot exists in SQLite
      final lotsInDb = await db.query('lots', where: 'product_id = ?', whereArgs: ['prod_1']);
      expect(lotsInDb.length, 1);
      expect(lotsInDb.first['current_quantity'], 15);

      // Verify sync_queue entries
      final syncQueue = await db.query('sync_queue', orderBy: 'created_at ASC');
      expect(syncQueue.length, 2);
      expect(syncQueue[0]['table_name'], 'products');
      expect(syncQueue[0]['operation'], 'CREATE');
      expect(syncQueue[1]['table_name'], 'lots');
      expect(syncQueue[1]['operation'], 'CREATE');
    });

    test('getAllProducts calculates availableStock reactively from active lots', () async {
      final product = ProductModel(
        id: 'prod_2',
        sku: 'SKU-002',
        name: 'Laptop Gamer',
        brand: 'Asus',
        category: 'Laptops',
        standardSellingPrice: 1200.0,
        minStockThreshold: 2,
      );

      final lot1 = LotModel(
        id: 'lot_2a',
        productId: 'prod_2',
        purchaseDate: DateTime.parse('2026-01-01T10:00:00Z'),
        initialQuantity: 10,
        currentQuantity: 7,
        realUnitCost: 800.0,
      );

      final lot2 = LotModel(
        id: 'lot_2b',
        productId: 'prod_2',
        purchaseDate: DateTime.parse('2026-02-01T10:00:00Z'),
        initialQuantity: 5,
        currentQuantity: 5,
        realUnitCost: 820.0,
      );

      await dataSource.saveProductWithInitialLot(product, lot1);
      await dataSource.addLotToProduct('prod_2', lot2);

      final products = await dataSource.getAllProducts();
      expect(products.length, 1);
      final retrieved = products.first;
      expect(retrieved.lots.length, 2);
      // Reactive stock sum: 7 + 5 = 12
      expect(retrieved.availableStock, 12);
      expect(retrieved.totalInvestedCapital, (7 * 800.0) + (5 * 820.0));
    });

    test('deleteProduct deletes product and lots in cascade and records sync_queue deletions', () async {
      final product = ProductModel(
        id: 'prod_3',
        sku: 'SKU-003',
        name: 'Tablet Lite',
        brand: 'Lenovo',
        category: 'Tablets',
        standardSellingPrice: 200.0,
        minStockThreshold: 2,
      );

      final lot = LotModel(
        id: 'lot_3',
        productId: 'prod_3',
        purchaseDate: DateTime.parse('2026-01-15T10:00:00Z'),
        initialQuantity: 8,
        currentQuantity: 8,
        realUnitCost: 120.0,
      );

      await dataSource.saveProductWithInitialLot(product, lot);

      // Now delete product
      await dataSource.deleteProduct('prod_3');

      // Verify both tables are empty for this product
      final products = await db.query('products', where: 'id = ?', whereArgs: ['prod_3']);
      final lots = await db.query('lots', where: 'product_id = ?', whereArgs: ['prod_3']);
      expect(products, isEmpty);
      expect(lots, isEmpty);

      // Verify sync_queue contains DELETE operations
      final deletes = await db.query(
        'sync_queue',
        where: 'operation = ?',
        whereArgs: ['DELETE'],
      );
      expect(deletes.length, 2);
      final lotDelete = deletes.firstWhere((d) => d['table_name'] == 'lots');
      final prodDelete = deletes.firstWhere((d) => d['table_name'] == 'products');
      expect(jsonDecode(lotDelete['payload'] as String)['id'], 'lot_3');
      expect(jsonDecode(prodDelete['payload'] as String)['id'], 'prod_3');
    });
  });
}
