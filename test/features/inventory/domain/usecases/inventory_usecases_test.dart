import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/models/product_model.dart';
import 'package:electronic_store/features/inventory/data/models/lot_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Inventory Domain & Logic', () {
    test('Validar cálculo de stock total por SKU sumando múltiples lotes', () {
      final product = Product(
        id: '1',
        sku: 'SKU-001',
        name: 'Test',
        brand: 'Brand',
        category: 'Cat',
        standardSellingPrice: 100,
        minStockThreshold: 5,
        lots: [
          Lot(id: 'L1', productId: '1', purchaseDate: DateTime.now(), initialQuantity: 10, currentQuantity: 10, realUnitCost: 50),
          Lot(id: 'L2', productId: '1', purchaseDate: DateTime.now(), initialQuantity: 5, currentQuantity: 5, realUnitCost: 60),
        ]
      );

      expect(product.availableStock, 15);
    });

    test('Validar alerta de stock bajo cuando el total sea menor o igual al stock mínimo', () {
      final productLow = Product(
        id: '1',
        sku: 'SKU-001',
        name: 'Test',
        brand: 'Brand',
        category: 'Cat',
        standardSellingPrice: 100,
        minStockThreshold: 5,
        lots: [
          Lot(id: 'L1', productId: '1', purchaseDate: DateTime.now(), initialQuantity: 5, currentQuantity: 5, realUnitCost: 50),
        ]
      );

      expect(productLow.status, StockStatus.lowStock);
      
      final productOut = productLow.copyWith(lots: []);
      expect(productOut.status, StockStatus.outOfStock);
    });
  });

  group('Sync Queue Registration', () {
    late Database db;
    late InventoryLocalDataSourceImpl localDataSource;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, version) async {
                await db.execute('''
                  CREATE TABLE IF NOT EXISTS products (
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
                  CREATE TABLE IF NOT EXISTS lots (
                      id TEXT PRIMARY KEY,
                      product_id TEXT NOT NULL,
                      purchase_date TEXT NOT NULL,
                      initial_quantity INTEGER NOT NULL,
                      current_quantity INTEGER NOT NULL,
                      real_unit_cost REAL NOT NULL,
                      promoter_base_price REAL,
                      is_active INTEGER DEFAULT 1,
                      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
                  );
                ''');
                await db.execute('''
                  CREATE TABLE IF NOT EXISTS sync_queue (
                      id TEXT PRIMARY KEY,
                      table_name TEXT NOT NULL,
                      operation TEXT NOT NULL,
                      payload TEXT NOT NULL,
                      created_at TEXT NOT NULL,
                      status TEXT DEFAULT 'PENDING',
                      retry_count INTEGER DEFAULT 0
                  );
                ''');
              }));
      localDataSource = InventoryLocalDataSourceImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Validar que al agregar una operación se registre en sync_queue', () async {
      final product = ProductModel(
        id: 'P1',
        sku: 'SKU-123',
        name: 'P',
        brand: 'B',
        category: 'C',
        standardSellingPrice: 10,
        minStockThreshold: 2,
      );
      final lot = LotModel(
        id: 'L1',
        productId: 'P1',
        purchaseDate: DateTime.now(),
        initialQuantity: 10,
        currentQuantity: 10,
        realUnitCost: 5,
      );

      await localDataSource.saveProductWithInitialLot(product, lot);

      final queue = await db.query('sync_queue');
      expect(queue.length, 2); // One for product, one for lot
      expect(queue[0]['table_name'], 'products');
      expect(queue[1]['table_name'], 'lots');
    });
  });
}
