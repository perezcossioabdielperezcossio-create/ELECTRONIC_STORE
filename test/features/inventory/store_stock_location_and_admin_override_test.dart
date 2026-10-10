import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/auth/presentation/widgets/admin_approval_dialog.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';
import 'package:electronic_store/features/inventory/data/models/lot_model.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/presentation/widgets/product_card.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/pos/data/models/sale_model.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}

class TestDbHelper implements DatabaseHelper {
  final Database db;
  TestDbHelper(this.db);
  @override
  Future<Database> get database async => db;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. Lot & Product Entity / Model Location Tests', () {
    test('Lot and LotModel defaults location to ALMACEN and handles TIENDA', () {
      final lotAlmacen = Lot(
        id: 'lot_1',
        productId: 'prod_1',
        purchaseDate: DateTime(2026, 1, 1),
        initialQuantity: 10,
        currentQuantity: 10,
        realUnitCost: 100.0,
      );

      expect(lotAlmacen.location, 'ALMACEN');
      expect(lotAlmacen.isAlmacen, true);
      expect(lotAlmacen.isTienda, false);

      final lotTienda = lotAlmacen.copyWith(location: 'TIENDA');
      expect(lotTienda.location, 'TIENDA');
      expect(lotTienda.isTienda, true);
      expect(lotTienda.isAlmacen, false);

      final lotModel = LotModel.fromEntity(lotTienda);
      final map = lotModel.toSqliteMap();
      expect(map['location'], 'TIENDA');

      final fromMap = LotModel.fromMap(map);
      expect(fromMap.location, 'TIENDA');
    });

    test('Product calculates stockInTienda and stockInAlmacen correctly', () {
      final product = Product(
        id: 'prod_1',
        sku: 'SKU-LOC-1',
        name: 'Smartphone Pro',
        brand: 'TechBrand',
        category: 'Telefonia',
        standardSellingPrice: 1500.0,
        minStockThreshold: 5,
        lots: [
          Lot(
            id: 'l_alm_1',
            productId: 'prod_1',
            purchaseDate: DateTime(2026, 1, 1),
            initialQuantity: 20,
            currentQuantity: 15,
            realUnitCost: 1000.0,
            location: 'ALMACEN',
          ),
          Lot(
            id: 'l_alm_2',
            productId: 'prod_1',
            purchaseDate: DateTime(2026, 1, 2),
            initialQuantity: 10,
            currentQuantity: 5,
            realUnitCost: 1050.0,
            location: 'ALMACEN',
          ),
          Lot(
            id: 'l_tnd_1',
            productId: 'prod_1',
            purchaseDate: DateTime(2026, 1, 3),
            initialQuantity: 8,
            currentQuantity: 6,
            realUnitCost: 1000.0,
            location: 'TIENDA',
          ),
        ],
      );

      expect(product.availableStock, 26); // 15 + 5 + 6
      expect(product.stockInAlmacen, 20); // 15 + 5
      expect(product.stockInTienda, 6);   // 6
    });
  });

  group('2. Contextual FIFO Discount by Location (TIENDA vs ALMACEN)', () {
    late Database db;
    late PosLocalDatasourceImpl posDs;

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
                is_active INTEGER DEFAULT 1
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
                retry_count INTEGER NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE sales (
                id TEXT PRIMARY KEY,
                created_at TEXT,
                fecha_venta TEXT,
                payment_method TEXT,
                metodo_pago TEXT,
                delivery_method TEXT,
                tipo_entrega TEXT,
                delivery_fee REAL DEFAULT 0,
                discount REAL DEFAULT 0,
                tax REAL DEFAULT 0,
                total REAL,
                total_cobrado REAL,
                status TEXT,
                customer_name TEXT,
                customer_phone TEXT,
                promoter_id TEXT,
                notes TEXT,
                cliente_id TEXT,
                delivery_id TEXT,
                delivery_name TEXT,
                repartidor_id TEXT,
                repartidor_nombre TEXT,
                is_locked INTEGER DEFAULT 0,
                store_location TEXT DEFAULT 'ALMACEN'
              );
            ''');
            await db.execute('''
              CREATE TABLE detalle_ventas (
                id TEXT PRIMARY KEY,
                venta_id TEXT NOT NULL,
                lote_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                product_name TEXT NOT NULL,
                cantidad INTEGER NOT NULL,
                costo_unitario_compra REAL NOT NULL,
                precio_unitario_cobrado REAL NOT NULL,
                line_discount REAL DEFAULT 0.0
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
          },
        ),
      );

      final dbHelper = TestDbHelper(db);
      posDs = PosLocalDatasourceImpl(dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    test('Seller FIFO only discounts from TIENDA location', () async {
      await db.insert('products', {
        'id': 'p1',
        'sku': 'SKU-FIFO-1',
        'name': 'Auriculares Bluetooth',
        'brand': 'SoundMax',
        'category': 'Audio',
        'standard_selling_price': 100.0,
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lot_alm',
        'product_id': 'p1',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 40.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lot_tnd',
        'product_id': 'p1',
        'purchase_date': '2026-01-02T00:00:00.000Z',
        'initial_quantity': 4,
        'current_quantity': 4,
        'real_unit_cost': 45.0,
        'location': 'TIENDA',
        'is_active': 1,
      });

      final saleTienda = SaleModel(
        id: 'sale_tnd_1',
        createdAt: DateTime.now(),
        items: const [
          SaleItem(productId: 'p1', productName: 'Auriculares Bluetooth', quantity: 3, unitPrice: 100.0),
        ],
        storeLocation: 'TIENDA',
      );

      await posDs.processSale(saleTienda);

      final lotTndDb = await db.query('lots', where: 'id = ?', whereArgs: ['lot_tnd']);
      expect(lotTndDb.first['current_quantity'], 1);

      final lotAlmDb = await db.query('lots', where: 'id = ?', whereArgs: ['lot_alm']);
      expect(lotAlmDb.first['current_quantity'], 10);
    });

    test('Admin can discount from ALMACEN location', () async {
      await db.insert('products', {
        'id': 'p2',
        'sku': 'SKU-FIFO-2',
        'name': 'Monitor Gamer',
        'brand': 'Vision',
        'category': 'Monitores',
        'standard_selling_price': 500.0,
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lot_alm_2',
        'product_id': 'p2',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 300.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lot_tnd_2',
        'product_id': 'p2',
        'purchase_date': '2026-01-02T00:00:00.000Z',
        'initial_quantity': 2,
        'current_quantity': 2,
        'real_unit_cost': 300.0,
        'location': 'TIENDA',
        'is_active': 1,
      });

      final saleAlmacen = SaleModel(
        id: 'sale_alm_1',
        createdAt: DateTime.now(),
        items: const [
          SaleItem(productId: 'p2', productName: 'Monitor Gamer', quantity: 3, unitPrice: 500.0),
        ],
        storeLocation: 'ALMACEN',
      );

      await posDs.processSale(saleAlmacen);

      final lotAlmDb = await db.query('lots', where: 'id = ?', whereArgs: ['lot_alm_2']);
      expect(lotAlmDb.first['current_quantity'], 2);

      final lotTndDb = await db.query('lots', where: 'id = ?', whereArgs: ['lot_tnd_2']);
      expect(lotTndDb.first['current_quantity'], 2);
    });
  });

  group('3. Role-Based ProductCard UI (Seller vs Admin)', () {
    testWidgets('Seller view displays tienda & almacen metrics and hides real costs', (tester) async {
      final product = Product(
        id: 'prod_role_1',
        sku: 'SKU-ROLE-1',
        name: 'Camara IP HD',
        brand: 'SecureView',
        category: 'Seguridad',
        standardSellingPrice: 250.0,
        minStockThreshold: 5,
        lots: [
          Lot(
            id: 'l_alm_r',
            productId: 'prod_role_1',
            purchaseDate: DateTime(2026, 1, 1),
            initialQuantity: 10,
            currentQuantity: 8,
            realUnitCost: 120.0,
            location: 'ALMACEN',
          ),
          Lot(
            id: 'l_tnd_r',
            productId: 'prod_role_1',
            purchaseDate: DateTime(2026, 1, 2),
            initialQuantity: 5,
            currentQuantity: 3,
            realUnitCost: 125.0,
            location: 'TIENDA',
          ),
        ],
      );

      final mockAuth = MockAuthViewModel();
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);
      when(() => mockAuth.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthViewModel>.value(
              value: mockAuth,
              child: ProductCard(product: product),
            ),
          ),
        ),
      );

      expect(find.text('Disponible en Tienda: 3'), findsOneWidget);
      expect(find.text('En Almacén Central: 8'), findsOneWidget);
      expect(find.textContaining('Bs. 250.00'), findsOneWidget);

      expect(find.textContaining('Último Costo'), findsNothing);
      expect(find.textContaining('120.00'), findsNothing);
      expect(find.textContaining('125.00'), findsNothing);

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('Admin view displays full metrics, lot location badges and cost information', (tester) async {
      final product = Product(
        id: 'prod_role_2',
        sku: 'SKU-ROLE-2',
        name: 'Router WiFi 6',
        brand: 'NetPro',
        category: 'Redes',
        standardSellingPrice: 400.0,
        minStockThreshold: 5,
        lots: [
          Lot(
            id: 'l_alm_r2',
            productId: 'prod_role_2',
            purchaseDate: DateTime(2026, 1, 1),
            initialQuantity: 10,
            currentQuantity: 8,
            realUnitCost: 200.0,
            location: 'ALMACEN',
          ),
          Lot(
            id: 'l_tnd_r2',
            productId: 'prod_role_2',
            purchaseDate: DateTime(2026, 1, 2),
            initialQuantity: 5,
            currentQuantity: 3,
            realUnitCost: 210.0,
            location: 'TIENDA',
          ),
        ],
      );

      final mockAuth = MockAuthViewModel();
      when(() => mockAuth.isAdmin).thenReturn(true);
      when(() => mockAuth.isSeller).thenReturn(false);
      when(() => mockAuth.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthViewModel>.value(
              value: mockAuth,
              child: ProductCard(product: product),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.textContaining('Último Costo'), findsOneWidget);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('ALMACEN'), findsOneWidget);
      expect(find.text('TIENDA'), findsOneWidget);
      expect(find.textContaining('Disp: 8/10 · Costo: Bs. 200.00'), findsOneWidget);
      expect(find.textContaining('Disp: 3/5 · Costo: Bs. 210.00'), findsOneWidget);
    });
  });

  group('4. Admin PIN Security & Deletion Safety (AdminApprovalDialog)', () {
    test('Master Admin PINs validation', () {
      expect(User.isValidAdminPin('696910'), true); // Abdiel
      expect(User.isValidAdminPin('000000'), true); // Arianna
      expect(User.isValidAdminPin('123456'), false);
      expect(User.isValidAdminPin(''), false);
      expect(User.isValidAdminPin('111111'), false);
    });

    testWidgets('AdminApprovalDialog accepts valid PIN and rejects invalid PIN', (tester) async {
      String? returnedPin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedPin = await showDialog<String>(
                    context: ctx,
                    builder: (_) => const AdminApprovalDialog(),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Autorización Admin'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '999999');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('PIN de Administrador inválido'), findsOneWidget);
      expect(returnedPin, isNull);

      await tester.enterText(find.byType(TextField), '696910');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(returnedPin, '696910');
    });

    test('Safe deletion: Physical delete when 0 sales, Soft delete when sales exist', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, sku TEXT, name TEXT, is_active INTEGER DEFAULT 1);');
            await db.execute('CREATE TABLE lots (id TEXT PRIMARY KEY, product_id TEXT, current_quantity INTEGER, is_active INTEGER DEFAULT 1, location TEXT DEFAULT "ALMACEN");');
            await db.execute('CREATE TABLE sync_queue (id TEXT PRIMARY KEY, table_name TEXT, operation TEXT, payload TEXT, created_at TEXT, status TEXT, retry_count INTEGER);');
            await db.execute('CREATE TABLE detalle_ventas (id TEXT PRIMARY KEY, venta_id TEXT, lote_id TEXT, product_id TEXT);');
          },
        ),
      );

      final ds = InventoryLocalDataSourceImpl(db);

      // Product 1: NO sales -> Physical delete
      await db.insert('products', {'id': 'p_no_sales', 'sku': 'SKU_1', 'name': 'Item 1', 'is_active': 1});
      await db.insert('lots', {'id': 'l_no_sales', 'product_id': 'p_no_sales', 'current_quantity': 5, 'is_active': 1});

      await ds.deleteLot('l_no_sales');
      final lotCheck1 = await db.query('lots', where: 'id = ?', whereArgs: ['l_no_sales']);
      expect(lotCheck1.isEmpty, true);

      await ds.deleteProduct('p_no_sales');
      final prodCheck1 = await db.query('products', where: 'id = ?', whereArgs: ['p_no_sales']);
      expect(prodCheck1.isEmpty, true);

      // Product 2: HAS sales in detalle_ventas -> Soft delete (is_active = 0)
      await db.insert('products', {'id': 'p_with_sales', 'sku': 'SKU_2', 'name': 'Item 2', 'is_active': 1});
      await db.insert('lots', {'id': 'l_with_sales', 'product_id': 'p_with_sales', 'current_quantity': 5, 'is_active': 1});
      await db.insert('detalle_ventas', {'id': 'dv_1', 'venta_id': 'v_1', 'lote_id': 'l_with_sales', 'product_id': 'p_with_sales'});

      await ds.deleteLot('l_with_sales');
      final lotCheck2 = await db.query('lots', where: 'id = ?', whereArgs: ['l_with_sales']);
      expect(lotCheck2.isNotEmpty, true);
      expect(lotCheck2.first['is_active'], 0);
      expect(lotCheck2.first['current_quantity'], 0);

      await ds.deleteProduct('p_with_sales');
      final prodCheck2 = await db.query('products', where: 'id = ?', whereArgs: ['p_with_sales']);
      expect(prodCheck2.isNotEmpty, true);
      expect(prodCheck2.first['is_active'], 0);

      await db.close();
    });
  });
}
