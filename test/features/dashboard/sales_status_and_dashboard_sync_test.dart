import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/features/pos/data/models/sale_model.dart';
import 'package:electronic_store/features/pos/domain/entities/sale.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/pos/domain/usecases/process_sale_usecase.dart';
import 'package:electronic_store/features/pos/data/repositories/pos_repository_impl.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electronic_store/core/sync/data/datasources/firestore_remote_data_source.dart';
import 'package:electronic_store/core/sync/data/models/sync_operation_model.dart';

class TestDbHelper implements DatabaseHelper {
  final Database db;
  TestDbHelper(this.db);

  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late Database db;
  late TestDbHelper dbHelper;
  late PosLocalDatasourceImpl posDs;
  late PosRepositoryImpl posRepo;
  late ProcessSaleUseCase processSaleUseCase;
  late DashboardLocalDatasourceImpl dashDs;
  late DashboardRepositoryImpl dashRepo;
  late GetDailyCashAuditUseCase getDailyCashAudit;
  late GetFinancialOverviewUseCase getFinancialOverview;
  late DashboardViewModel dashboardVm;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
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
                standard_selling_price REAL NOT NULL,
                is_active INTEGER DEFAULT 1
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
                is_active INTEGER DEFAULT 1
            );
          ''');
          await db.execute('''
            CREATE TABLE ventas (
                id TEXT PRIMARY KEY,
                cliente_id TEXT,
                total_cobrado REAL NOT NULL,
                metodo_pago TEXT NOT NULL,
                tipo_entrega TEXT NOT NULL,
                fecha_venta TEXT NOT NULL,
                is_locked INTEGER DEFAULT 0,
                created_at TEXT DEFAULT (datetime('now')),
                payment_method TEXT,
                delivery_method TEXT,
                delivery_fee REAL DEFAULT 0.0,
                discount REAL DEFAULT 0.0,
                tax REAL DEFAULT 0.0,
                total REAL,
                status TEXT DEFAULT 'COMPLETED',
                customer_name TEXT,
                customer_phone TEXT,
                promoter_id TEXT,
                delivery_id TEXT,
                delivery_name TEXT,
                notes TEXT,
                usuario_id TEXT,
                origen_venta TEXT DEFAULT 'ALMACEN',
                store_location TEXT DEFAULT 'ALMACEN'
            );
          ''');
          await db.execute('''
            CREATE TABLE detalle_ventas (
                id TEXT PRIMARY KEY,
                venta_id TEXT NOT NULL,
                lote_id TEXT,
                product_id TEXT,
                product_name TEXT,
                cantidad INTEGER NOT NULL,
                costo_unitario_compra REAL NOT NULL,
                precio_unitario_cobrado REAL NOT NULL,
                line_discount REAL DEFAULT 0.0
            );
          ''');
          await db.execute('''
            CREATE TABLE sales (
                id TEXT PRIMARY KEY,
                cliente_id TEXT,
                total_cobrado REAL,
                metodo_pago TEXT,
                tipo_entrega TEXT,
                fecha_venta TEXT,
                created_at TEXT DEFAULT (datetime('now')),
                payment_method TEXT NOT NULL,
                delivery_method TEXT NOT NULL,
                delivery_fee REAL DEFAULT 0.0,
                discount REAL DEFAULT 0.0,
                tax REAL DEFAULT 0.0,
                total REAL NOT NULL,
                status TEXT DEFAULT 'COMPLETED',
                customer_name TEXT,
                customer_phone TEXT,
                promoter_id TEXT,
                delivery_id TEXT,
                delivery_name TEXT,
                notes TEXT,
                is_locked INTEGER DEFAULT 0,
                usuario_id TEXT,
                origen_venta TEXT DEFAULT 'ALMACEN',
                store_location TEXT DEFAULT 'ALMACEN'
            );
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
            );
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
                id TEXT PRIMARY KEY,
                table_name TEXT NOT NULL,
                operation TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                retry_count INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE usuarios (
                celular TEXT PRIMARY KEY,
                nombre TEXT NOT NULL,
                pin TEXT NOT NULL,
                role TEXT NOT NULL,
                tienda_nombre TEXT NOT NULL,
                activo INTEGER NOT NULL DEFAULT 1
            );
          ''');
        },
      ),
    );

    dbHelper = TestDbHelper(db);
    posDs = PosLocalDatasourceImpl(dbHelper);
    posRepo = PosRepositoryImpl(posDs);
    processSaleUseCase = ProcessSaleUseCase(posRepo);
    dashDs = DashboardLocalDatasourceImpl(dbHelper);
    dashRepo = DashboardRepositoryImpl(dashDs);
    getDailyCashAudit = GetDailyCashAuditUseCase(dashRepo);
    getFinancialOverview = GetFinancialOverviewUseCase(dashRepo);
    dashboardVm = DashboardViewModel(
      getFinancialOverview: getFinancialOverview,
      getDailyCashAudit: getDailyCashAudit,
      dashboardRepository: dashRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Sale Status & Persistence: SQLite, Sync Queue & Firestore', () {
    test('Successful POS sale persists is_locked = 1 and status = COMPLETED in SQLite ventas & sales', () async {
      // Setup product and lot
      await db.insert('products', {
        'id': 'p1',
        'sku': 'SKU-001',
        'name': 'Auriculares Bluetooth',
        'standard_selling_price': 150.0,
      });
      await db.insert('lots', {
        'id': 'l1',
        'product_id': 'p1',
        'purchase_date': '2026-10-10T10:00:00Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 70.0,
        'location': 'ALMACEN',
      });

      final sale = Sale(
        id: 'sale-test-01',
        items: const [
          SaleItem(
            productId: 'p1',
            productName: 'Auriculares Bluetooth',
            quantity: 2,
            unitPrice: 150.0,
          ),
        ],
        createdAt: DateTime.parse('2026-10-10T12:00:00.000'),
        paymentMethod: 'EFECTIVO',
        deliveryMethod: 'TIENDA',
        storeLocation: 'ALMACEN',
      );

      final result = await processSaleUseCase(ProcessSaleParams(sale));
      expect(result.isRight(), isTrue);

      // Verify SQLite ventas table
      final ventasRows = await db.query('ventas', where: 'id = ?', whereArgs: ['sale-test-01']);
      expect(ventasRows.isNotEmpty, isTrue);
      expect(ventasRows.first['is_locked'], 1);
      expect(ventasRows.first['status'], 'COMPLETED');

      // Verify SQLite sales table
      final salesRows = await db.query('sales', where: 'id = ?', whereArgs: ['sale-test-01']);
      expect(salesRows.isNotEmpty, isTrue);
      expect(salesRows.first['is_locked'], 1);
      expect(salesRows.first['status'], 'COMPLETED');

      // Verify sync_queue payload
      final syncRows = await db.query('sync_queue', where: "table_name = 'sales'");
      expect(syncRows.isNotEmpty, isTrue);
      final payload = jsonDecode(syncRows.first['payload'] as String) as Map<String, dynamic>;
      expect(payload['status'], 'COMPLETED');
      expect(payload['is_locked'], true);
    });

    test('FirestoreRemoteDataSource pushes status: COMPLETED and is_locked: true to Firestore sales', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockCol = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      Map<String, dynamic>? savedData;

      when(() => mockFirestore.collection('sales')).thenReturn(mockCol);
      when(() => mockCol.doc(any())).thenReturn(mockDoc);
      when(() => mockDoc.set(any(), any())).thenAnswer((inv) async {
        savedData = inv.positionalArguments[0] as Map<String, dynamic>;
      });

      final firestoreDs = FirestoreRemoteDataSource(firestore: mockFirestore);

      final saleModel = SaleModel(
        id: 'sale-remote-01',
        items: const [
          SaleItem(
            productId: 'p1',
            productName: 'Auriculares Bluetooth',
            quantity: 1,
            unitPrice: 150.0,
          ),
        ],
        createdAt: DateTime.parse('2026-10-10T14:30:00.000'),
        paymentMethod: 'EFECTIVO',
        deliveryMethod: 'TIENDA',
        status: SaleStatus.completed,
        isLocked: true,
      );

      final op = SyncOperationModel(
        id: 'op-01',
        tableName: 'sales',
        operation: 'CREATE',
        payload: jsonEncode(saleModel.toMap()),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        status: 'PENDING',
      );

      final syncResult = await firestoreDs.syncOperation(op);
      expect(syncResult.success, isTrue);
      expect(savedData, isNotNull);
      expect(savedData!['status'], 'COMPLETED');
      expect(savedData!['is_locked'], true);
    });
  });

  group('2. Date Normalization for Dashboard Queries (YYYY-MM-DD and ISO-8601)', () {
    test('getArqueoDiario and getSalesByDate compute all sales on 2026-10-10 regardless of time format and timezone', () async {
      // 1. Sale with ISO timestamp with T and timezone
      await db.insert('ventas', {
        'id': 'v-iso-tz',
        'total_cobrado': 100.0,
        'metodo_pago': 'EFECTIVO',
        'tipo_entrega': 'TIENDA',
        'fecha_venta': '2026-10-10T08:15:30.123-04:00',
        'created_at': '2026-10-10T08:15:30.123-04:00',
        'payment_method': 'EFECTIVO',
        'delivery_method': 'TIENDA',
        'total': 100.0,
        'status': 'COMPLETED',
        'is_locked': 1,
        'origen_venta': 'ALMACEN',
      });
      await db.insert('detalle_ventas', {
        'id': 'dv-1',
        'venta_id': 'v-iso-tz',
        'product_name': 'Item 1',
        'cantidad': 1,
        'costo_unitario_compra': 50.0,
        'precio_unitario_cobrado': 100.0,
      });

      // 2. Sale with legacy status: "pending" (not voided)
      await db.insert('ventas', {
        'id': 'v-legacy-pending',
        'total_cobrado': 200.0,
        'metodo_pago': 'QR',
        'tipo_entrega': 'TIENDA',
        'fecha_venta': '2026-10-10 23:59:59',
        'created_at': '2026-10-10 23:59:59',
        'payment_method': 'QR',
        'delivery_method': 'TIENDA',
        'total': 200.0,
        'status': 'pending',
        'is_locked': 1,
        'origen_venta': 'ALMACEN',
      });
      await db.insert('detalle_ventas', {
        'id': 'dv-2',
        'venta_id': 'v-legacy-pending',
        'product_name': 'Item 2',
        'cantidad': 2,
        'costo_unitario_compra': 60.0,
        'precio_unitario_cobrado': 100.0,
      });

      // 3. Voided sale on the same date (MUST be excluded)
      await db.insert('ventas', {
        'id': 'v-voided',
        'total_cobrado': 500.0,
        'metodo_pago': 'EFECTIVO',
        'tipo_entrega': 'TIENDA',
        'fecha_venta': '2026-10-10T15:00:00Z',
        'created_at': '2026-10-10T15:00:00Z',
        'payment_method': 'EFECTIVO',
        'delivery_method': 'TIENDA',
        'total': 500.0,
        'status': 'VOIDED',
        'is_locked': 1,
        'origen_venta': 'ALMACEN',
      });

      // 4. Sale on a different date (2026-10-11, MUST be excluded)
      await db.insert('ventas', {
        'id': 'v-diff-date',
        'total_cobrado': 300.0,
        'metodo_pago': 'EFECTIVO',
        'tipo_entrega': 'TIENDA',
        'fecha_venta': '2026-10-11T10:00:00Z',
        'created_at': '2026-10-11T10:00:00Z',
        'payment_method': 'EFECTIVO',
        'delivery_method': 'TIENDA',
        'total': 300.0,
        'status': 'COMPLETED',
        'is_locked': 1,
        'origen_venta': 'ALMACEN',
      });

      final targetDate = DateTime(2026, 10, 10);

      // Verify getArqueoDiario sums both non-voided sales (100 + 200 = 300)
      final arqueo = await dashDs.getArqueoDiario(date: targetDate);
      expect(arqueo.ingresoBrutoTotal, 300.0);
      expect(arqueo.capitalBaseRecuperadoTotal, 170.0); // 50 + 120 = 170
      expect(arqueo.desglose.length, 2);

      // Verify getSalesByDate returns the 2 non-voided sales on 2026-10-10
      final salesByDate = await posDs.getSalesByDate(targetDate);
      expect(salesByDate.length, 2);
      final saleIds = salesByDate.map((s) => s.id).toList();
      expect(saleIds, contains('v-iso-tz'));
      expect(saleIds, contains('v-legacy-pending'));
      expect(saleIds, isNot(contains('v-voided')));
      expect(saleIds, isNot(contains('v-diff-date')));
    });
  });

  group('3. Immediate Reactivity (loadAuditForDate)', () {
    test('DashboardViewModel.loadAuditForDate reloads audit and sales for the target date', () async {
      final targetDate = DateTime(2026, 10, 10);
      await dashboardVm.loadAuditForDate(targetDate);

      expect(dashboardVm.selectedDate, targetDate);
      expect(dashboardVm.state, DashboardState.loaded);
    });
  });
}
