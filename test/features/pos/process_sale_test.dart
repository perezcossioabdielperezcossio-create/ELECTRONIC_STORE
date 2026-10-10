import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/features/pos/data/models/sale_model.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/pos/domain/entities/sale.dart';
import 'package:electronic_store/core/errors/exceptions.dart';

import 'package:mocktail/mocktail.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late Database db;
  late PosLocalDatasourceImpl datasource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sales(
            id TEXT PRIMARY KEY,
            created_at TEXT DEFAULT (datetime('now')),
            payment_method TEXT NOT NULL,
            delivery_method TEXT NOT NULL,
            delivery_fee REAL DEFAULT 0.0,
            discount REAL DEFAULT 0.0,
            tax REAL DEFAULT 0.0,
            total REAL NOT NULL,
            status TEXT DEFAULT 'pending',
            customer_name TEXT,
            customer_phone TEXT,
            promoter_id TEXT,
            notes TEXT,
            is_locked INTEGER DEFAULT 0,
            FOREIGN KEY (promoter_id) REFERENCES promoters(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items(
            id TEXT PRIMARY KEY,
            sale_id TEXT,
            product_id TEXT,
            product_name TEXT,
            quantity INTEGER,
            unit_price REAL,
            unit_cost REAL,
            line_discount REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE lots(
            id TEXT PRIMARY KEY,
            product_id TEXT,
            purchase_date TEXT,
            initial_quantity INTEGER,
            current_quantity INTEGER,
            real_unit_cost REAL,
            promoter_base_price REAL,
            location TEXT NOT NULL DEFAULT 'ALMACEN',
            is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue(
            id TEXT PRIMARY KEY,
            table_name TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            status TEXT DEFAULT 'PENDING',
            retry_count INTEGER DEFAULT 0
          )
        ''');
      },
    ));

    final mockDbHelper = MockDatabaseHelper();
    when(() => mockDbHelper.database).thenAnswer((_) async => db);
    datasource = PosLocalDatasourceImpl(mockDbHelper);

    // Seed some lots
    await db.insert('lots', {
      'id': 'lot_1',
      'product_id': 'prod_A',
      'purchase_date': '2023-01-01T00:00:00Z',
      'initial_quantity': 10,
      'current_quantity': 10,
      'real_unit_cost': 50.0,
    });

    await db.insert('lots', {
      'id': 'lot_2',
      'product_id': 'prod_A',
      'purchase_date': '2023-02-01T00:00:00Z',
      'initial_quantity': 5,
      'current_quantity': 5,
      'real_unit_cost': 60.0, // More expensive new lot
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('processSale FIFO & Anti-loss', () {
    test('Successful sale spanning 2 lots (FIFO cascade)', () async {
      // Act: Sell 12 units of prod_A at 100.0 each
      final sale = SaleModel(
        id: 'sale_1',
        items: const [
          SaleItem(
            productId: 'prod_A',
            productName: 'Product A',
            quantity: 12,
            unitPrice: 100.0,
          )
        ],
        createdAt: DateTime.now(),
        status: SaleStatus.completed,
      );

      await datasource.processSale(sale);

      // Assert
      final lots = await db.query('lots', orderBy: 'purchase_date ASC');
      // lot_1 should be depleted (10 - 10 = 0)
      expect(lots[0]['current_quantity'], 0);
      // lot_2 should have 3 left (5 - 2 = 3)
      expect(lots[1]['current_quantity'], 3);
    });

    test('Throws InsufficientStockException when sale exceeds total active stock', () async {
      // Act: Sell 20 units of prod_A (total stock is 15)
      final sale = SaleModel(
        id: 'sale_2',
        items: const [
          SaleItem(
            productId: 'prod_A',
            productName: 'Product A',
            quantity: 20,
            unitPrice: 100.0,
          )
        ],
        createdAt: DateTime.now(),
        status: SaleStatus.completed,
      );

      // Assert
      expect(
        () => datasource.processSale(sale),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('Throws AntiLossException when net unit price is below lot cost', () async {
      // Act: Sell 1 unit of prod_A with a unit price below the cost of lot_1 (50.0)
      final sale = SaleModel(
        id: 'sale_3',
        items: const [
          SaleItem(
            productId: 'prod_A',
            productName: 'Product A',
            quantity: 1,
            unitPrice: 40.0, // Below realUnitCost of 50.0
          )
        ],
        createdAt: DateTime.now(),
        status: SaleStatus.completed,
      );

      // Assert
      expect(
        () => datasource.processSale(sale),
        throwsA(isA<AntiLossException>()),
      );
    });
  });
}
