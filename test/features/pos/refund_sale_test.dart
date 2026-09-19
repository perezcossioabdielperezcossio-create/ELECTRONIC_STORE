import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/core/errors/exceptions.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'dart:io';

void main() {
  late Database db;
  late PosLocalDatasourceImpl datasource;

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
        standard_selling_price REAL NOT NULL,
        min_stock_threshold INTEGER DEFAULT 5,
        is_active INTEGER DEFAULT 1
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
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        delivery_method TEXT NOT NULL,
        total REAL NOT NULL,
        status TEXT DEFAULT 'pending',
        is_locked INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL DEFAULT 0.0,
        line_discount REAL DEFAULT 0.0
      )
    ''');

    datasource = PosLocalDatasourceImpl(DatabaseHelperMock(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('refundSale reintegrates stock and changes status when within 24h', () async {
    // 1. Arrange: Create product and lot
    await db.insert('products', {
      'id': 'p1',
      'sku': 'SKU1',
      'name': 'Test Product',
      'standard_selling_price': 100.0,
    });

    await db.insert('lots', {
      'id': 'l1',
      'product_id': 'p1',
      'purchase_date': DateTime.now().toIso8601String(),
      'initial_quantity': 50,
      'current_quantity': 45, // Assuming 5 were sold
      'real_unit_cost': 40.0,
    });

    final recentDate = DateTime.now().subtract(const Duration(hours: 2));

    await db.insert('sales', {
      'id': 's1',
      'created_at': recentDate.toIso8601String(),
      'payment_method': 'EFECTIVO',
      'delivery_method': 'TIENDA',
      'total': 500.0,
      'status': 'pending',
    });

    await db.insert('sale_items', {
      'id': 'si1',
      'sale_id': 's1',
      'product_id': 'p1',
      'product_name': 'Test Product',
      'quantity': 5,
      'unit_price': 100.0,
    });

    // 2. Act
    await datasource.refundSale('s1');

    // 3. Assert
    final saleResult = await db.query('sales', where: 'id = ?', whereArgs: ['s1']);
    expect(saleResult.first['status'], 'refunded');

    final lotResult = await db.query('lots', where: 'id = ?', whereArgs: ['l1']);
    expect(lotResult.first['current_quantity'], 50); // 45 + 5
  });

  test('refundSale throws RefundWindowExpiredException when older than 24h', () async {
    // 1. Arrange
    await db.insert('products', {
      'id': 'p1',
      'sku': 'SKU1',
      'name': 'Test Product',
      'standard_selling_price': 100.0,
    });

    await db.insert('lots', {
      'id': 'l1',
      'product_id': 'p1',
      'purchase_date': DateTime.now().toIso8601String(),
      'initial_quantity': 50,
      'current_quantity': 45,
      'real_unit_cost': 40.0,
    });

    final oldDate = DateTime.now().subtract(const Duration(hours: 25));

    await db.insert('sales', {
      'id': 's2',
      'created_at': oldDate.toIso8601String(),
      'payment_method': 'EFECTIVO',
      'delivery_method': 'TIENDA',
      'total': 500.0,
      'status': 'pending',
    });

    await db.insert('sale_items', {
      'id': 'si2',
      'sale_id': 's2',
      'product_id': 'p1',
      'product_name': 'Test Product',
      'quantity': 5,
      'unit_price': 100.0,
    });

    // 2. Act & Assert
    expect(
      () => datasource.refundSale('s2'),
      throwsA(isA<RefundWindowExpiredException>()),
    );

    // Verify stock is not altered
    final lotResult = await db.query('lots', where: 'id = ?', whereArgs: ['l1']);
    expect(lotResult.first['current_quantity'], 45); // unchanged
  });
}

class DatabaseHelperMock implements DatabaseHelper {
  final Database db;
  DatabaseHelperMock(this.db);
  
  @override
  Future<Database> get database async => db;

}
