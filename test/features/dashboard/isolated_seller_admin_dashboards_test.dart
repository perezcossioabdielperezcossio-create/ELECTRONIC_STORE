import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/errors/exceptions.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/features/pos/data/models/sale_model.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:electronic_store/features/dashboard/presentation/views/seller_dashboard_view.dart';
import 'package:electronic_store/features/dashboard/presentation/views/dashboard_overview_view.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}

class FakeDbHelper implements DatabaseHelper {
  final Database db;
  FakeDbHelper(this.db);

  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Database db;
  late FakeDbHelper dbHelper;
  late PosLocalDatasourceImpl posDs;
  late DashboardLocalDatasourceImpl dashDs;
  late DashboardRepositoryImpl dashRepo;
  late GetFinancialOverviewUseCase getFinancialOverview;
  late GetDailyCashAuditUseCase getDailyCashAudit;
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

    dbHelper = FakeDbHelper(db);
    posDs = PosLocalDatasourceImpl(dbHelper);
    dashDs = DashboardLocalDatasourceImpl(dbHelper);
    dashRepo = DashboardRepositoryImpl(dashDs);
    getFinancialOverview = GetFinancialOverviewUseCase(dashRepo);
    getDailyCashAudit = GetDailyCashAuditUseCase(dashRepo);
    dashboardVm = DashboardViewModel(
      getFinancialOverview: getFinancialOverview,
      getDailyCashAudit: getDailyCashAudit,
      dashboardRepository: dashRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Strict FIFO Location Isolation', () {
    test('Store sale (TIENDA) strictly consumes lots with location == TIENDA', () async {
      await db.insert('products', {
        'id': 'prod_1',
        'sku': 'SKU1',
        'name': 'Mouse Gamer',
        'standard_selling_price': 100.0,
      });

      // Lote 1 en ALMACEN con 10 unidades
      await db.insert('lots', {
        'id': 'lot_almacen',
        'product_id': 'prod_1',
        'purchase_date': '2026-01-01T00:00:00Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 50.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      // Lote 2 en TIENDA con 3 unidades
      await db.insert('lots', {
        'id': 'lot_tienda',
        'product_id': 'prod_1',
        'purchase_date': '2026-01-02T00:00:00Z',
        'initial_quantity': 3,
        'current_quantity': 3,
        'real_unit_cost': 55.0,
        'location': 'TIENDA',
        'is_active': 1,
      });

      // Venta de 2 unidades desde TIENDA
      final storeSale = SaleModel(
        id: 'sale_store_1',
        items: const [
          SaleItem(
            productId: 'prod_1',
            productName: 'Mouse Gamer',
            quantity: 2,
            unitPrice: 100.0,
          ),
        ],
        createdAt: DateTime.now(),
        storeLocation: 'TIENDA',
        usuarioId: '70011223',
      );

      await posDs.processSale(storeSale);

      // Verificar que el lote de TIENDA disminuyó a 1 y el de ALMACEN quedó intacto en 10
      final tiendaLot = (await db.query('lots', where: 'id = ?', whereArgs: ['lot_tienda'])).first;
      final almacenLot = (await db.query('lots', where: 'id = ?', whereArgs: ['lot_almacen'])).first;

      expect(tiendaLot['current_quantity'], 1);
      expect(almacenLot['current_quantity'], 10);
    });

    test('Store sale throws InsufficientStockException if TIENDA has not enough stock even if ALMACEN has stock', () async {
      await db.insert('products', {
        'id': 'prod_1',
        'sku': 'SKU1',
        'name': 'Mouse Gamer',
        'standard_selling_price': 100.0,
      });

      await db.insert('lots', {
        'id': 'lot_almacen',
        'product_id': 'prod_1',
        'purchase_date': '2026-01-01T00:00:00Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 50.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lot_tienda',
        'product_id': 'prod_1',
        'purchase_date': '2026-01-02T00:00:00Z',
        'initial_quantity': 2,
        'current_quantity': 2,
        'real_unit_cost': 55.0,
        'location': 'TIENDA',
        'is_active': 1,
      });

      final storeSale = SaleModel(
        id: 'sale_store_2',
        items: const [
          SaleItem(
            productId: 'prod_1',
            productName: 'Mouse Gamer',
            quantity: 5, // Requires 5, but TIENDA only has 2
            unitPrice: 100.0,
          ),
        ],
        createdAt: DateTime.now(),
        storeLocation: 'TIENDA',
        usuarioId: '70011223',
      );

      expect(() => posDs.processSale(storeSale), throwsA(isA<InsufficientStockException>()));
    });
  });

  group('2. Seller Dashboard UI & Privacy', () {
    testWidgets('SellerDashboardView displays only seller sales and hides profit and capital metrics', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockAuthViewModel();
      const seller = UserModel(
        celular: '77700011',
        nombre: 'Carlos Vendedor',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal Central',
        activo: true,
      );

      when(() => mockAuth.currentUser).thenReturn(seller);
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);

      // Insert seller's sale (TIENDA) into independent ventas_vendedor table
      final now = DateTime.now();
      await tester.runAsync(() async {
        await db.insert('ventas_vendedor', {
          'id': 'sale_seller_1',
          'usuario_id': '77700011',
          'vendedor_nombre': 'Carlos Vendedor',
          'cliente_nombre': 'Cliente Prueba',
          'fecha_venta': now.toIso8601String(),
          'total_cobrado': 350.0,
          'metodo_pago': 'EFECTIVO',
          'status': 'COMPLETED',
          'is_locked': 1,
          'items': jsonEncode([
            {
              'product_id': 'prod_1',
              'product_name': 'Producto 1',
              'cantidad': 1,
              'precio_unitario': 350.0,
            }
          ]),
        });

        // Insert another sale from warehouse (ALMACEN) - should not appear in seller dashboard
        await db.insert('sales', {
          'id': 'sale_admin_warehouse',
          'total_cobrado': 2000.0,
          'metodo_pago': 'QR',
          'tipo_entrega': 'TIENDA',
          'delivery_method': 'TIENDA',
          'fecha_venta': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'payment_method': 'QR',
          'total': 2000.0,
          'status': 'completed',
          'usuario_id': '70000000',
          'origen_venta': 'ALMACEN',
          'store_location': 'ALMACEN',
        });

        await dashboardVm.loadSellerDashboardData('77700011');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: mockAuth),
            ChangeNotifierProvider<DashboardViewModel>.value(value: dashboardVm),
          ],
          child: const MaterialApp(
            home: SellerDashboardView(),
          ),
        ),
      );

      await tester.pump();

      // Cards
      expect(find.text('Mi Dashboard'), findsOneWidget);
      expect(find.text('Ventas Hoy'), findsOneWidget);
      expect(find.text('Ventas Esta Semana'), findsOneWidget);
      expect(find.text('Arqueo de Mi Caja (Hoy)'), findsOneWidget);

      // Verifies prohibited metrics are NOT present
      expect(find.textContaining('Capital Inmovilizado'), findsNothing);
      expect(find.textContaining('Ganancia Neta Real'), findsNothing);
      expect(find.textContaining('Margen Neto'), findsNothing);
      expect(find.textContaining('Costo Real'), findsNothing);

      // Verify seller's own sale is listed and warehouse sale is excluded
      expect(find.textContaining('Venta #sale_sel'), findsOneWidget);
      expect(find.textContaining('sale_admin'), findsNothing);
    });
  });

  group('3. Admin Dashboard Audit Filtering', () {
    testWidgets('DashboardOverviewView renders filter segmented button and shows capital metrics', (tester) async {
      await tester.runAsync(() async {
        await db.insert('usuarios', {
          'celular': '77700011',
          'nombre': 'Carlos Vendedor',
          'pin': '123456',
          'role': 'seller',
          'tienda_nombre': 'Sucursal Central',
          'activo': 1,
        });
        await dashboardVm.loadDashboardData();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardViewModel>.value(
          value: dashboardVm,
          child: const MaterialApp(
            home: DashboardOverviewView(),
          ),
        ),
      );

      await tester.pump();

      // Header filter
      expect(find.text('Almacén Central'), findsOneWidget);
      expect(find.text('Consolidado'), findsOneWidget);
      expect(find.text('Por Vendedor'), findsOneWidget);

      // Admin exclusive KPIs
      expect(find.text('Capital Inmovilizado'), findsOneWidget);
      expect(find.text('Ganancia Neta Real'), findsOneWidget);

      // Switch to Por Vendedor
      await tester.runAsync(() async {
        await tester.tap(find.text('Por Vendedor'));
        await dashboardVm.setAdminFilter(AdminDashboardFilter.porVendedor);
      });
      await tester.pump();

      expect(dashboardVm.adminFilter, AdminDashboardFilter.porVendedor);
    });
  });
}
