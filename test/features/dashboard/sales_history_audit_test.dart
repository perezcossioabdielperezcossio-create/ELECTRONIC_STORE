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

/// Creates a minimal schema that mirrors the production tables used by
/// [DashboardLocalDatasourceImpl.getSalesAuditHistory].
Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS products (
      id   TEXT PRIMARY KEY,
      sku  TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      standard_selling_price REAL NOT NULL
    )
  ''');

  // Primary warehouse sales tables
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ventas (
      id             TEXT PRIMARY KEY,
      fecha_venta    TEXT,
      created_at     TEXT DEFAULT (datetime('now')),
      metodo_pago    TEXT NOT NULL DEFAULT 'EFECTIVO',
      tipo_entrega   TEXT NOT NULL DEFAULT 'MOSTRADOR',
      total_cobrado  REAL NOT NULL DEFAULT 0,
      origen_venta   TEXT NOT NULL DEFAULT 'ALMACEN',
      status         TEXT NOT NULL DEFAULT 'COMPLETED',
      usuario_id     TEXT,
      cliente_id     TEXT,
      cliente_nombre TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS detalle_ventas (
      id                     TEXT PRIMARY KEY,
      venta_id               TEXT NOT NULL,
      producto_id            TEXT NOT NULL,
      cantidad               INTEGER NOT NULL,
      costo_unitario_compra  REAL NOT NULL DEFAULT 0,
      precio_unitario_cobrado REAL NOT NULL,
      descuento_linea        REAL DEFAULT 0,
      FOREIGN KEY(venta_id) REFERENCES ventas(id)
    )
  ''');

  // Seller store sales tables (used for TIENDA queries)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ventas_vendedor (
      id             TEXT PRIMARY KEY,
      fecha_venta    TEXT NOT NULL,
      metodo_pago    TEXT NOT NULL DEFAULT 'EFECTIVO',
      total_cobrado  REAL NOT NULL DEFAULT 0,
      status         TEXT NOT NULL DEFAULT 'COMPLETED',
      usuario_id     TEXT,
      cliente_nombre TEXT,
      items          TEXT
    )
  ''');

  // Legacy fallback tables (kept for old dashboard_metrics_test compatibility)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sales (
      id             TEXT PRIMARY KEY,
      created_at     TEXT DEFAULT (datetime('now')),
      payment_method TEXT NOT NULL,
      total          REAL NOT NULL,
      promoter_id    TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_items (
      id           TEXT PRIMARY KEY,
      sale_id      TEXT NOT NULL,
      product_id   TEXT NOT NULL,
      quantity     INTEGER NOT NULL,
      unit_price   REAL NOT NULL,
      unit_cost    REAL DEFAULT 0.0
    )
  ''');
}

void main() {
  late Database db;
  late DashboardLocalDatasourceImpl datasource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => _createSchema(db),
      ),
    );
    datasource = DashboardLocalDatasourceImpl(FakeDatabaseHelper(db));
  });

  tearDown(() async => db.close());

  // ─── helpers ───────────────────────────────────────────────────────────────

  Future<void> insertVenta(
    String id, {
    required String fecha,
    String metodo = 'EFECTIVO',
    String origen = 'ALMACEN',
    String? clienteNombre,
    double total = 0.0,
  }) =>
      db.insert('ventas', {
        'id': id,
        'fecha_venta': fecha,
        'metodo_pago': metodo,
        'origen_venta': origen,
        'cliente_nombre': clienteNombre,
        'total_cobrado': total,
      });

  Future<void> insertDetalle(
    String id, {
    required String ventaId,
    required String productoId,
    required int cantidad,
    required double costo,
    required double precio,
  }) =>
      db.insert('detalle_ventas', {
        'id': id,
        'venta_id': ventaId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'costo_unitario_compra': costo,
        'precio_unitario_cobrado': precio,
      });

  // ─── tests ─────────────────────────────────────────────────────────────────

  group('getSalesAuditHistory — ventas × detalle_ventas JOIN', () {
    test('returns one entry per detail line, ordered newest first', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      await db.insert('products', {
        'id': 'p1',
        'sku': 'SKU-001',
        'name': 'Auricular BT',
        'standard_selling_price': 120.0,
      });

      // Venta 1 — 09:00 (earlier)
      await insertVenta('v1', fecha: '${todayStr}T09:00:00');
      await insertDetalle('dv1',
          ventaId: 'v1', productoId: 'p1', cantidad: 2, costo: 50.0, precio: 120.0);

      // Venta 2 — 11:00 (later → should be first in result)
      await insertVenta('v2', fecha: '${todayStr}T11:00:00', metodo: 'QR');
      await insertDetalle('dv2a',
          ventaId: 'v2', productoId: 'p1', cantidad: 1, costo: 50.0, precio: 120.0);
      await insertDetalle('dv2b',
          ventaId: 'v2', productoId: 'p1', cantidad: 3, costo: 50.0, precio: 115.0);

      final entries = await datasource.getSalesAuditHistory(
        date: today,
        origenVenta: 'ALMACEN',
      );

      // 1 detail from v1  +  2 details from v2  = 3 total
      expect(entries.length, 3);

      // Newest (v2) should come first
      expect(entries.first.ventaId, 'v2');
      expect(entries.first.metodoPago, 'QR');

      // product name resolved via JOIN with products table
      expect(entries.first.productName, 'Auricular BT');
      expect(entries.first.sku, 'SKU-001');
    });

    test('computes ganancia and lineTotal correctly', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      await insertVenta('v1', fecha: '${todayStr}T08:00:00');
      await insertDetalle('dv1',
          ventaId: 'v1',
          productoId: 'PROD-X',
          cantidad: 4,
          costo: 25.0,
          precio: 60.0);

      final entries = await datasource.getSalesAuditHistory(date: today);
      expect(entries.length, 1);

      final e = entries.first;
      // lineTotal = 60 * 4 = 240
      expect(e.lineTotal, closeTo(240.0, 0.001));
      // totalCosto = 25 * 4 = 100
      expect(e.totalCosto, closeTo(100.0, 0.001));
      // ganancia = 240 - 100 = 140
      expect(e.ganancia, closeTo(140.0, 0.001));
    });

    test('returns empty list when no ventas on selected date', () async {
      final pastDate = DateTime(2020, 1, 1);
      final entries = await datasource.getSalesAuditHistory(date: pastDate);
      expect(entries, isEmpty);
    });

    test('clienteNombre falls back to "Mostrador" when null', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      await insertVenta('v1', fecha: '${todayStr}T07:00:00'); // clienteNombre = null
      await insertDetalle('dv1',
          ventaId: 'v1', productoId: 'P', cantidad: 1, costo: 10.0, precio: 20.0);

      final entries = await datasource.getSalesAuditHistory(date: today);
      expect(entries.first.clienteNombre, 'Mostrador');
    });

    test('ALMACEN filter excludes ventas with origen_venta = TIENDA', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      await insertVenta('v-almacen', fecha: '${todayStr}T10:00:00', origen: 'ALMACEN');
      await insertDetalle('dv-a',
          ventaId: 'v-almacen', productoId: 'P', cantidad: 1, costo: 10.0, precio: 30.0);

      await insertVenta('v-tienda', fecha: '${todayStr}T10:05:00', origen: 'TIENDA');
      await insertDetalle('dv-t',
          ventaId: 'v-tienda', productoId: 'P', cantidad: 2, costo: 10.0, precio: 30.0);

      final entries = await datasource.getSalesAuditHistory(
        date: today,
        origenVenta: 'ALMACEN',
      );

      // Only the ALMACEN row should appear
      expect(entries.length, 1);
      expect(entries.first.ventaId, 'v-almacen');
    });

    test('multiple detail lines per sale produce one entry per line', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      await insertVenta('v1', fecha: '${todayStr}T09:30:00');
      for (var i = 1; i <= 5; i++) {
        await insertDetalle('dv$i',
            ventaId: 'v1', productoId: 'P$i', cantidad: i, costo: 10.0, precio: 20.0);
      }

      final entries = await datasource.getSalesAuditHistory(date: today);
      expect(entries.length, 5);
      // All belong to the same venta
      expect(entries.every((e) => e.ventaId == 'v1'), isTrue);
    });

    test('getAllSalesHistory returns all sales across different dates ordered DESC', () async {
      await insertVenta('v-old', fecha: '2026-01-01T10:00:00');
      await insertDetalle('dv-old', ventaId: 'v-old', productoId: 'P1', cantidad: 1, costo: 5.0, precio: 15.0);

      await insertVenta('v-new', fecha: '2026-10-14T10:00:00');
      await insertDetalle('dv-new', ventaId: 'v-new', productoId: 'P1', cantidad: 2, costo: 5.0, precio: 15.0);

      final entries = await datasource.getAllSalesHistory();
      expect(entries.length, 2);
      expect(entries.first.ventaId, 'v-new');
      expect(entries.last.ventaId, 'v-old');
    });

    test('LEFT JOIN ensures sales without detalle_ventas records still appear with defaults', () async {
      await insertVenta('v-no-details', fecha: '2026-10-14T11:00:00', total: 180.0);

      final entries = await datasource.getAllSalesHistory();
      final orphanEntry = entries.firstWhere((e) => e.ventaId == 'v-no-details');
      expect(orphanEntry.productName, 'Venta General');
      expect(orphanEntry.cantidad, 1);
      expect(orphanEntry.precioUnitario, 180.0);
      expect(orphanEntry.costoUnitario, 0.0);
      expect(orphanEntry.sku, '-');
      expect(orphanEntry.detalleId, 'v-no-details_det');
    });
  });

  group('getSalesAuditHistory — fallback sales/sale_items', () {
    test('resolves data from legacy sales table when ventas is empty', () async {
      // Drop primary tables so the fallback kicks in
      await db.execute('DROP TABLE IF EXISTS ventas');
      await db.execute('DROP TABLE IF EXISTS detalle_ventas');

      final today = DateTime.now();
      final dateStr = '${today.toIso8601String().substring(0, 10)} 10:00:00';

      await db.insert('sales', {
        'id': 's1',
        'created_at': dateStr,
        'payment_method': 'EFECTIVO',
        'total': 200.0,
      });
      await db.insert('sale_items', {
        'id': 'si1',
        'sale_id': 's1',
        'product_id': 'p1',
        'quantity': 2,
        'unit_price': 100.0,
        'unit_cost': 50.0,
      });

      final entries = await datasource.getSalesAuditHistory(date: today);
      expect(entries.length, 1);
      expect(entries.first.ventaId, 's1');
      expect(entries.first.cantidad, 2);
      expect(entries.first.precioUnitario, 100.0);
      expect(entries.first.costoUnitario, 50.0);
    });
  });
}
