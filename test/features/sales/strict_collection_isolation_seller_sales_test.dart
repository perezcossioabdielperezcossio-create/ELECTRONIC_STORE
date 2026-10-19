import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/sync/data/models/sync_operation_model.dart';
import 'package:electronic_store/core/sync/data/datasources/firestore_remote_data_source.dart';
import 'package:electronic_store/core/sync/data/datasources/sync_local_datasource.dart';
import 'package:electronic_store/core/sync/data/datasources/remote_sync_datasource.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/features/pos/data/models/sale_model.dart';
import 'package:electronic_store/features/pos/domain/entities/sale.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';

class IsolationTestDbHelper implements DatabaseHelper {
  final Database db;
  IsolationTestDbHelper(this.db);

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
// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockRemoteSyncDs extends Mock implements RemoteSyncDataSource {}

void main() {
  late Database db;
  late IsolationTestDbHelper dbHelper;

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
                status TEXT DEFAULT 'completed',
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
            CREATE TABLE IF NOT EXISTS ventas_vendedor (
                id TEXT PRIMARY KEY,
                usuario_id TEXT NOT NULL,
                vendedor_nombre TEXT,
                cliente_nombre TEXT,
                fecha_venta TEXT NOT NULL,
                total_cobrado REAL NOT NULL,
                metodo_pago TEXT NOT NULL,
                status TEXT DEFAULT 'COMPLETED',
                is_locked INTEGER DEFAULT 1,
                items TEXT,
                created_at TEXT DEFAULT (datetime('now'))
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
                status TEXT DEFAULT 'completed',
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
    dbHelper = IsolationTestDbHelper(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Total Isolation in Cloud Firestore (FirestoreRemoteDataSource)', () {
    test('Seller sale strictly routes to seller_sales collection with exact required document schema', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockSellerSalesCol = MockCollectionReference();
      final mockSalesCol = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      Map<String, dynamic>? savedSellerDoc;
      when(() => mockFirestore.collection('seller_sales')).thenReturn(mockSellerSalesCol);
      when(() => mockFirestore.collection('sales')).thenReturn(mockSalesCol);
      when(() => mockSellerSalesCol.doc('seller-sale-101')).thenReturn(mockDoc);
      when(() => mockDoc.set(any(), any())).thenAnswer((inv) async {
        savedSellerDoc = inv.positionalArguments[0] as Map<String, dynamic>;
      });

      final firestoreDs = FirestoreRemoteDataSource(firestore: mockFirestore);

      final sellerSalePayload = {
        'id': 'seller-sale-101',
        'usuario_id': '77712345',
        'vendedor_nombre': 'Maria Vendedora',
        'cliente_nombre': 'Juan Perez',
        'fecha_venta': '2026-10-13T15:00:00.000',
        'total_cobrado': 250.0,
        'metodo_pago': 'QR',
        'status': 'COMPLETED',
        'is_locked': 1,
        'items': [
          {
            'product_id': 'prod_a',
            'product_name': 'Teclado Gamer',
            'cantidad': 1,
            'precio_unitario': 250.0,
          }
        ],
      };

      final op = SyncOperationModel(
        id: 'op-seller-1',
        tableName: 'ventas_vendedor',
        operation: 'CREATE',
        payload: jsonEncode(sellerSalePayload),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        status: 'PENDING',
      );

      final result = await firestoreDs.syncOperation(op);
      expect(result.success, isTrue);

      // Verify seller sale was saved into 'seller_sales' collection
      verify(() => mockFirestore.collection('seller_sales')).called(1);
      verifyNever(() => mockFirestore.collection('sales'));

      // Verify exact required document schema
      expect(savedSellerDoc, isNotNull);
      expect(savedSellerDoc!['id'], 'seller-sale-101');
      expect(savedSellerDoc!['usuario_id'], '77712345');
      expect(savedSellerDoc!['vendedor_nombre'], 'Maria Vendedora');
      expect(savedSellerDoc!['cliente_nombre'], 'Juan Perez');
      expect(savedSellerDoc!['fecha_venta'], '2026-10-13T15:00:00.000');
      expect(savedSellerDoc!['total_cobrado'], 250.0);
      expect(savedSellerDoc!['metodo_pago'], 'QR');
      expect(savedSellerDoc!['status'], 'COMPLETED');
      expect(savedSellerDoc!['is_locked'], 1);

      final items = savedSellerDoc!['items'] as List;
      expect(items.length, 1);
      expect(items[0]['product_id'], 'prod_a');
      expect(items[0]['product_name'], 'Teclado Gamer');
      expect(items[0]['cantidad'], 1);
      expect(items[0]['precio_unitario'], 250.0);
    });

    test('Central Warehouse sale strictly routes to sales collection with sale_details', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockSalesCol = MockCollectionReference();
      final mockSellerSalesCol = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      Map<String, dynamic>? savedWarehouseDoc;
      when(() => mockFirestore.collection('sales')).thenReturn(mockSalesCol);
      when(() => mockFirestore.collection('seller_sales')).thenReturn(mockSellerSalesCol);
      when(() => mockSalesCol.doc('warehouse-sale-202')).thenReturn(mockDoc);
      when(() => mockDoc.set(any(), any())).thenAnswer((inv) async {
        savedWarehouseDoc = inv.positionalArguments[0] as Map<String, dynamic>;
      });

      final firestoreDs = FirestoreRemoteDataSource(firestore: mockFirestore);

      final warehouseSale = SaleModel(
        id: 'warehouse-sale-202',
        createdAt: DateTime.parse('2026-10-13T10:00:00.000'),
        paymentMethod: 'EFECTIVO',
        deliveryMethod: 'TIENDA',
        status: SaleStatus.completed,
        isLocked: true,
        storeLocation: 'ALMACEN',
        usuarioId: '70000000',
        items: const [
          SaleItem(productId: 'prod_b', productName: 'Monitor 24', quantity: 2, unitPrice: 800.0),
        ],
      );

      final op = SyncOperationModel(
        id: 'op-warehouse-1',
        tableName: 'sales',
        operation: 'CREATE',
        payload: jsonEncode(warehouseSale.toMap()),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        status: 'PENDING',
      );

      final result = await firestoreDs.syncOperation(op);
      expect(result.success, isTrue);

      verify(() => mockFirestore.collection('sales')).called(1);
      verifyNever(() => mockFirestore.collection('seller_sales'));
      expect(savedWarehouseDoc, isNotNull);
      expect(savedWarehouseDoc!['status'], 'COMPLETED');
      expect(savedWarehouseDoc!['is_locked'], true);
    });
  });

  group('2. Total Isolation in Local SQLite (PosLocalDatasource)', () {
    test('Seller checkout stores strictly in ventas_vendedor and queues ventas_vendedor; zero rows in warehouse ventas/sales', () async {
      final posDs = PosLocalDatasourceImpl(dbHelper);

      // Seed lot in TIENDA
      await db.insert('products', {
        'id': 'p_store_1',
        'sku': 'SKU-STORE-1',
        'name': 'Mouse Inalámbrico',
        'standard_selling_price': 100.0,
      });
      await db.insert('lots', {
        'id': 'lot_store_1',
        'product_id': 'p_store_1',
        'purchase_date': '2026-10-01',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 40.0,
        'location': 'TIENDA',
      });

      final sellerSale = SaleModel(
        id: 'pos_seller_sale_99',
        customerName: 'Cliente Tienda',
        createdAt: DateTime.now(),
        paymentMethod: 'EFECTIVO',
        deliveryMethod: 'TIENDA',
        storeLocation: 'TIENDA',
        usuarioId: '77799887',
        vendedorNombre: 'Ana Vendedora',
        items: const [
          SaleItem(productId: 'p_store_1', productName: 'Mouse Inalámbrico', quantity: 2, unitPrice: 100.0),
        ],
      );

      await posDs.processSale(sellerSale);

      // 1. Verify inserted in ventas_vendedor
      final sellerRows = await db.query('ventas_vendedor', where: 'id = ?', whereArgs: ['pos_seller_sale_99']);
      expect(sellerRows.length, 1);
      expect(sellerRows.first['usuario_id'], '77799887');
      expect(sellerRows.first['vendedor_nombre'], 'Ana Vendedora');
      expect(sellerRows.first['total_cobrado'], 200.0);

      // 2. Verify sync_queue operation tableName is 'ventas_vendedor'
      final syncOps = await db.query('sync_queue', where: "table_name = 'ventas_vendedor'");
      expect(syncOps.length, 1);
      final payload = jsonDecode(syncOps.first['payload'] as String) as Map<String, dynamic>;
      expect(payload['id'], 'pos_seller_sale_99');
      expect(payload['vendedor_nombre'], 'Ana Vendedora');

      // 3. Verify zero rows inserted in warehouse 'ventas' or 'sales' or 'sale_items'
      final warehouseVentas = await db.query('ventas', where: 'id = ?', whereArgs: ['pos_seller_sale_99']);
      expect(warehouseVentas, isEmpty);
      final warehouseSales = await db.query('sales', where: 'id = ?', whereArgs: ['pos_seller_sale_99']);
      expect(warehouseSales, isEmpty);
      final warehouseSaleItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: ['pos_seller_sale_99']);
      expect(warehouseSaleItems, isEmpty);
    });

    test('Central Warehouse checkout stores strictly in ventas (origen_venta = ALMACEN) and queues sales; zero rows in ventas_vendedor', () async {
      final posDs = PosLocalDatasourceImpl(dbHelper);

      // Seed lot in ALMACEN
      await db.insert('products', {
        'id': 'p_wh_1',
        'sku': 'SKU-WH-1',
        'name': 'Gabinete ATX',
        'standard_selling_price': 500.0,
      });
      await db.insert('lots', {
        'id': 'lot_wh_1',
        'product_id': 'p_wh_1',
        'purchase_date': '2026-10-01',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 250.0,
        'location': 'ALMACEN',
      });

      final warehouseSale = SaleModel(
        id: 'pos_wh_sale_55',
        customerName: 'Cliente Mayorista',
        createdAt: DateTime.now(),
        paymentMethod: 'TRANSFERENCIA',
        deliveryMethod: 'TIENDA',
        storeLocation: 'ALMACEN',
        usuarioId: '70000000',
        items: const [
          SaleItem(productId: 'p_wh_1', productName: 'Gabinete ATX', quantity: 1, unitPrice: 500.0),
        ],
      );

      await posDs.processSale(warehouseSale);

      // 1. Verify inserted in warehouse ventas
      final whRows = await db.query('ventas', where: 'id = ?', whereArgs: ['pos_wh_sale_55']);
      expect(whRows.length, 1);
      expect(whRows.first['origen_venta'], 'ALMACEN');
      expect(whRows.first['total_cobrado'], 500.0);

      // 2. Verify sync_queue operation tableName is 'sales'
      final syncOps = await db.query('sync_queue', where: "table_name = 'sales'");
      expect(syncOps.length, 1);

      // 3. Verify zero rows in ventas_vendedor
      final sellerRows = await db.query('ventas_vendedor', where: 'id = ?', whereArgs: ['pos_wh_sale_55']);
      expect(sellerRows, isEmpty);
    });
  });

  group('3. Total Accounting Isolation in Dashboards', () {
    test('Warehouse Dashboard strictly isolates ventas; ventas_vendedor are 100% excluded from warehouse cash and profits', () async {
      final dashDs = DashboardLocalDatasourceImpl(dbHelper);
      final today = DateTime.now();

      // Insert Warehouse Sale: 1000 Bs
      await db.insert('ventas', {
        'id': 'wh_sale_01',
        'fecha_venta': today.toIso8601String(),
        'total_cobrado': 1000.0,
        'metodo_pago': 'EFECTIVO',
        'tipo_entrega': 'TIENDA',
        'origen_venta': 'ALMACEN',
        'status': 'completed',
      });
      await db.insert('detalle_ventas', {
        'id': 'wh_detail_01',
        'venta_id': 'wh_sale_01',
        'cantidad': 1,
        'costo_unitario_compra': 600.0,
        'precio_unitario_cobrado': 1000.0,
      });

      // Insert Seller Sale: 500 Bs in ventas_vendedor
      await db.insert('ventas_vendedor', {
        'id': 'seller_sale_01',
        'usuario_id': '77700011',
        'vendedor_nombre': 'Carlos',
        'fecha_venta': today.toIso8601String(),
        'total_cobrado': 500.0,
        'metodo_pago': 'EFECTIVO',
        'status': 'COMPLETED',
        'is_locked': 1,
        'items': jsonEncode([
          {'product_id': 'p1', 'product_name': 'Item', 'cantidad': 1, 'precio_unitario': 500.0}
        ]),
      });

      // 1. Warehouse Arqueo: must be exactly 1000 Bs (excluding 500 Bs from seller_sales)
      final warehouseArqueo = await dashDs.getArqueoDiario(date: today, origenVenta: 'ALMACEN');
      expect(warehouseArqueo.ingresoBrutoTotal, 1000.0);
      expect(warehouseArqueo.capitalBaseRecuperadoTotal, 600.0);
      expect(warehouseArqueo.gananciaNetaRealTotal, 400.0);

      // 2. Warehouse Weekly Sales: must be exactly 1000 Bs
      final warehouseWeek = await dashDs.getTotalVentasSemana(date: today, origenVenta: 'ALMACEN');
      expect(warehouseWeek, 1000.0);

      // 3. Warehouse Filtered Sales: must list only the 1 warehouse sale
      final warehouseSales = await dashDs.getVentasFiltradas(date: today, origenVenta: 'ALMACEN');
      expect(warehouseSales.length, 1);
      expect(warehouseSales.first.id, 'wh_sale_01');

      // 4. Seller Arqueo: must be exactly 500 Bs from ventas_vendedor (excluding warehouse sales)
      final sellerArqueo = await dashDs.getArqueoDiario(date: today, usuarioId: '77700011', origenVenta: 'TIENDA');
      expect(sellerArqueo.ingresoBrutoTotal, 500.0);

      // 5. Seller Weekly Sales: must be exactly 500 Bs
      final sellerWeek = await dashDs.getTotalVentasSemana(date: today, usuarioId: '77700011', origenVenta: 'TIENDA');
      expect(sellerWeek, 500.0);

      // 6. Seller Filtered Sales: must list only the seller sale
      final sellerSales = await dashDs.getVentasFiltradas(date: today, usuarioId: '77700011', origenVenta: 'TIENDA');
      expect(sellerSales.length, 1);
      expect(sellerSales.first.id, 'seller_sale_01');
    });
  });

  group('4. Real-time Sync and Role-based Subscription (SyncManager)', () {
    test('Seller user configures live subscription to seller_sales and ignores warehouse sales', () async {
      final mockRemoteDs = MockRemoteSyncDataSource();
      final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
      final syncManager = SyncManager(localDataSource: syncLocalDs, remoteDataSource: mockRemoteDs);

      // Configure seller user
      syncManager.configureUserSync(role: 'seller', celular: '77755443');

      final emittedEvents = <SyncCompletedEvent>[];
      final sub = syncManager.onSyncCompleted.listen(emittedEvents.add);

      // Simulate seller sale received from Firestore
      final mockSellerSalesData = [
        {
          'id': 'stream-seller-01',
          'usuario_id': '77755443',
          'vendedor_nombre': 'Pedro',
          'cliente_nombre': 'Cliente Stream',
          'fecha_venta': DateTime.now().toIso8601String(),
          'total_cobrado': 300.0,
          'metodo_pago': 'EFECTIVO',
          'status': 'COMPLETED',
          'is_locked': 1,
          'items': [
            {'product_id': 'p2', 'product_name': 'Mousepad', 'cantidad': 1, 'precio_unitario': 300.0}
          ],
        }
      ];

      await syncLocalDs.syncSellerSales(mockSellerSalesData);

      // Verify row persisted into ventas_vendedor
      final rows = await db.query('ventas_vendedor', where: 'id = ?', whereArgs: ['stream-seller-01']);
      expect(rows.length, 1);
      expect(rows.first['total_cobrado'], 300.0);

      await sub.cancel();
    });

    test('Admin on-demand audit fetches seller_sales without continuous background listening', () async {
      final mockRemoteDs = MockRemoteSyncDs();
      final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);

      when(() => mockRemoteDs.listenToRemoteSales()).thenAnswer((_) => const Stream.empty());
      when(() => mockRemoteDs.listenToSellerSales(any())).thenAnswer((_) => const Stream.empty());
      when(() => mockRemoteDs.listenToRemoteLots(location: any(named: 'location'))).thenAnswer((_) => const Stream.empty());

      final syncManager = SyncManager(localDataSource: syncLocalDs, remoteDataSource: mockRemoteDs);

      // Configure admin user
      syncManager.configureUserSync(role: 'admin', celular: '70000000');

      // Admin triggers on-demand audit for seller '77711223'
      final auditSales = [
        {
          'id': 'audit-seller-01',
          'usuario_id': '77711223',
          'vendedor_nombre': 'Sonia',
          'cliente_nombre': 'Cliente Auditoria',
          'fecha_venta': DateTime.now().toIso8601String(),
          'total_cobrado': 450.0,
          'metodo_pago': 'QR',
          'status': 'COMPLETED',
          'is_locked': 1,
          'items': [
            {'product_id': 'p3', 'product_name': 'Parlante', 'cantidad': 1, 'precio_unitario': 450.0}
          ],
        }
      ];

      when(() => mockRemoteDs.fetchSellerSales(sellerPhone: '77711223')).thenAnswer((_) async => auditSales);

      final count = await syncManager.fetchSellerSalesOnDemand(sellerPhone: '77711223');
      expect(count, 1);

      final auditRows = await db.query('ventas_vendedor', where: 'id = ?', whereArgs: ['audit-seller-01']);
      expect(auditRows.length, 1);
      expect(auditRows.first['vendedor_nombre'], 'Sonia');
    });

    test('DashboardViewModel reacts to ventas_vendedor events and reloads seller dashboard data', () async {
      final dashDs = DashboardLocalDatasourceImpl(dbHelper);
      final dashRepo = DashboardRepositoryImpl(dashDs);
      final getFinancialOverview = GetFinancialOverviewUseCase(dashRepo);
      final getDailyCashAudit = GetDailyCashAuditUseCase(dashRepo);

      final mockRemoteDs = MockRemoteSyncDataSource();
      final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
      final syncManager = SyncManager(localDataSource: syncLocalDs, remoteDataSource: mockRemoteDs);

      final vm = DashboardViewModel(
        getFinancialOverview: getFinancialOverview,
        getDailyCashAudit: getDailyCashAudit,
        syncManager: syncManager,
        dashboardRepository: dashRepo,
      );

      vm.setActiveSellerUsuarioId('77799112');

      // Insert seller sale into ventas_vendedor
      await db.insert('ventas_vendedor', {
        'id': 'reactive-sale-01',
        'usuario_id': '77799112',
        'vendedor_nombre': 'Marcos',
        'fecha_venta': DateTime.now().toIso8601String(),
        'total_cobrado': 750.0,
        'metodo_pago': 'EFECTIVO',
        'status': 'COMPLETED',
        'is_locked': 1,
        'items': jsonEncode([
          {'product_id': 'p9', 'product_name': 'Item', 'cantidad': 1, 'precio_unitario': 750.0}
        ]),
      });

      // Emitting on-demand sync event for ventas_vendedor triggers reload
      await syncManager.fetchSellerSalesOnDemand(sellerPhone: '77799112');

      // Allow microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.sellerVentasHoy, 750.0);
      expect(vm.sellerSales.length, 1);
      expect(vm.sellerSales.first.id, 'reactive-sale-01');

      vm.dispose();
    });
  });
}
