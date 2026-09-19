import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/core/database/database_helper.dart';
class FakeDatabaseHelper implements DatabaseHelper {
  final Database db;
  FakeDatabaseHelper(this.db);
  
  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Database db;
  late DashboardLocalDatasourceImpl datasource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
              id TEXT PRIMARY KEY,
              sku TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              standard_selling_price REAL NOT NULL,
              is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE lots (
              id TEXT PRIMARY KEY,
              product_id TEXT NOT NULL,
              current_quantity INTEGER NOT NULL,
              real_unit_cost REAL NOT NULL,
              is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
              id TEXT PRIMARY KEY,
              created_at TEXT DEFAULT (datetime('now')),
              payment_method TEXT NOT NULL,
              total REAL NOT NULL,
              promoter_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              unit_price REAL NOT NULL,
              unit_cost REAL DEFAULT 0.0
          )
        ''');
      },
    ));

    datasource = DashboardLocalDatasourceImpl(FakeDatabaseHelper(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('getBalancePatrimonial calculates correctly', () async {
    await db.insert('products', {'id': 'p1', 'sku': '1', 'name': 'P1', 'standard_selling_price': 100.0});
    await db.insert('lots', {'id': 'l1', 'product_id': 'p1', 'current_quantity': 10, 'real_unit_cost': 50.0});

    final result = await datasource.getBalancePatrimonial();

    // Inmovilizado: 10 * 50 = 500
    // Potencial: 10 * (100 - 50) = 500
    expect(result.capitalInmovilizado, 500.0);
    expect(result.gananciaPotencial, 500.0);
  });

  test('getArqueoDiario calculates correctly', () async {
    final now = DateTime.now();
    final dateStr = '${now.toIso8601String().substring(0, 10)} 10:00:00';

    await db.insert('sales', {'id': 's1', 'created_at': dateStr, 'payment_method': 'EFECTIVO', 'total': 200.0});
    await db.insert('sale_items', {'id': 'si1', 'sale_id': 's1', 'product_id': 'p1', 'quantity': 2, 'unit_price': 100.0, 'unit_cost': 50.0});

    final result = await datasource.getArqueoDiario(date: now);

    expect(result.ingresoBrutoTotal, 200.0);
    expect(result.capitalBaseRecuperadoTotal, 100.0); // 2 * 50
    expect(result.gananciaNetaRealTotal, 100.0); // 200 - 100
    expect(result.desglose.length, 1);
    expect(result.desglose.first.metodo, 'EFECTIVO');
  });

  test('getMetricasCanal calculates correctly', () async {
    final now = DateTime.now();
    final dateStr = '${now.toIso8601String().substring(0, 10)} 10:00:00';

    // Directa
    await db.insert('sales', {'id': 's1', 'created_at': dateStr, 'payment_method': 'EFECTIVO', 'total': 200.0, 'promoter_id': null});
    await db.insert('sale_items', {'id': 'si1', 'sale_id': 's1', 'product_id': 'p1', 'quantity': 2, 'unit_price': 100.0, 'unit_cost': 50.0});

    // Promotor
    await db.insert('sales', {'id': 's2', 'created_at': dateStr, 'payment_method': 'EFECTIVO', 'total': 300.0, 'promoter_id': 'prom1'});
    await db.insert('sale_items', {'id': 'si2', 'sale_id': 's2', 'product_id': 'p2', 'quantity': 3, 'unit_price': 100.0, 'unit_cost': 60.0});

    final result = await datasource.getMetricasCanal();

    expect(result.length, 2);
    final directa = result.firstWhere((m) => m.canal == 'Venta Directa');
    final promotor = result.firstWhere((m) => m.canal == 'Red de Promotores');

    expect(directa.totalIngresos, 200.0);
    expect(directa.totalCostos, 100.0);
    
    expect(promotor.totalIngresos, 300.0);
    expect(promotor.totalCostos, 180.0); // 3 * 60
  });
}
