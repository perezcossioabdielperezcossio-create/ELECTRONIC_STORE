import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;

import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:electronic_store/features/inventory/domain/usecases/add_inventory_batch.dart';
import 'package:electronic_store/features/inventory/domain/usecases/consume_stock_fifo.dart';
import 'package:electronic_store/features/inventory/domain/usecases/create_product_with_lot_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/delete_product_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/delete_lot_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/get_all_products.dart';
import 'package:electronic_store/features/inventory/domain/usecases/update_product_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/transfer_stock_to_store_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/revert_or_adjust_store_stock_usecase.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/inventory/presentation/screens/admin_store_inventory_screen.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}

void main() {
  late Database db;
  late InventoryLocalDataSourceImpl invLocalDs;
  late InventoryRepositoryImpl invRepo;
  late TransferStockToStoreUseCase transferStockToStoreUseCase;
  late RevertOrAdjustStoreStockUseCase revertOrAdjustStoreStockUseCase;
  late InventoryViewModel inventoryVm;
  late MockAuthViewModel mockAuth;

  final adminUser = const UserModel(
    celular: '67606367',
    nombre: 'Abdiel Perez Cossio',
    pin: '696910',
    role: UserRole.admin,
    tiendaNombre: 'Almacén Central',
  );

  final sellerUser = const User(
    celular: '77700011',
    nombre: 'Carlos Vendedor',
    pin: '123456',
    role: UserRole.seller,
    tiendaNombre: 'Sucursal Central',
  );

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
            CREATE TABLE ventas (
              id TEXT PRIMARY KEY,
              total_cobrado REAL,
              usuario_id TEXT,
              origen_venta TEXT DEFAULT 'ALMACEN',
              store_location TEXT DEFAULT 'ALMACEN',
              fecha_venta TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE detalle_ventas (
              id TEXT PRIMARY KEY,
              venta_id TEXT NOT NULL,
              product_id TEXT,
              cantidad INTEGER,
              precio_unitario_cobrado REAL
            );
          ''');
          await db.execute('''
            CREATE TABLE usuarios (
              celular TEXT PRIMARY KEY,
              nombre TEXT NOT NULL,
              pin TEXT NOT NULL,
              role TEXT NOT NULL,
              tienda_nombre TEXT,
              activo INTEGER DEFAULT 1
            );
          ''');
        },
      ),
    );

    invLocalDs = InventoryLocalDataSourceImpl(db);
    invRepo = InventoryRepositoryImpl(invLocalDs);
    transferStockToStoreUseCase = TransferStockToStoreUseCase(invRepo);
    revertOrAdjustStoreStockUseCase = RevertOrAdjustStoreStockUseCase(invRepo);

    inventoryVm = InventoryViewModel(
      getAllProductsUseCase: GetAllProducts(invRepo),
      addLotUseCase: AddLotUseCase(invRepo),
      consumeStockUseCase: ConsumeStockFifo(invRepo),
      createProductWithLotUseCase: CreateProductWithLotUseCase(invRepo),
      updateProductUseCase: UpdateProductUseCase(invRepo),
      deleteProductUseCase: DeleteProductUseCase(invRepo),
      deleteLotUseCase: DeleteLotUseCase(invRepo),
      transferStockToStoreUseCase: transferStockToStoreUseCase,
      revertOrAdjustStoreStockUseCase: revertOrAdjustStoreStockUseCase,
    );

    mockAuth = MockAuthViewModel();
    when(() => mockAuth.currentUser).thenReturn(adminUser);
    when(() => mockAuth.isAdmin).thenReturn(true);
    when(() => mockAuth.isSeller).thenReturn(false);

    // Insert sample user
    await db.insert('usuarios', {
      'celular': sellerUser.celular,
      'nombre': sellerUser.nombre,
      'pin': sellerUser.pin,
      'role': 'seller',
      'tienda_nombre': sellerUser.tiendaNombre,
      'activo': 1,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Lógica Transaccional de Transferencias (TransferStockToStoreUseCase)', () {
    test('Transfiere stock de Almacén a Tienda respetando FIFO y sin generar ventas', () async {
      // 1. Insert product
      await db.insert('products', {
        'id': 'prod_01',
        'sku': 'SKU-01',
        'name': 'Laptop Dell Latitude',
        'brand': 'Dell',
        'category': 'Computación',
        'standard_selling_price': 4500.0,
      });

      // 2. Insert two lots in ALMACEN (Oldest: 5 units @ cost 3000, Newest: 10 units @ cost 3200)
      await db.insert('lots', {
        'id': 'lot_alm_old',
        'product_id': 'prod_01',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 3000.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });
      await db.insert('lots', {
        'id': 'lot_alm_new',
        'product_id': 'prod_01',
        'purchase_date': '2026-02-01T00:00:00.000Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 3200.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      // 3. Transfer 7 units to Tienda (5 from oldest, 2 from newest)
      final result = await transferStockToStoreUseCase(
        const TransferStockToStoreParams(
          productId: 'prod_01',
          quantity: 7,
          sellerId: '77700011',
          storeLocation: 'TIENDA',
        ),
      );

      expect(result.isRight(), true);

      // Verify FIFO on Almacén lots
      final lotOld = await db.query('lots', where: 'id = ?', whereArgs: ['lot_alm_old']);
      expect(lotOld.first['current_quantity'], 0);

      final lotNew = await db.query('lots', where: 'id = ?', whereArgs: ['lot_alm_new']);
      expect(lotNew.first['current_quantity'], 8);

      // Verify TIENDA lots created with inherited costs
      final tiendaLots = await db.query('lots', where: "location = 'TIENDA'");
      expect(tiendaLots.length, 2);
      final totalTiendaQty = tiendaLots.fold<int>(0, (sum, l) => sum + (l['current_quantity'] as int));
      expect(totalTiendaQty, 7);

      // Verify that NO sales or detalle_ventas records were created
      final salesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ventas')) ?? 0;
      final detailsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM detalle_ventas')) ?? 0;
      expect(salesCount, 0);
      expect(detailsCount, 0);

      // Verify sync_queue operations were recorded
      final syncQueueLots = await db.query('sync_queue', where: "table_name = 'lots'");
      expect(syncQueueLots.length >= 4, true); // 2 updates for warehouse lots, 2 creates for store lots
    });

    test('Rechaza transferir si cantidad solicitada supera existencias de Almacén', () async {
      await db.insert('products', {
        'id': 'prod_low',
        'sku': 'SKU-LOW',
        'name': 'Mouse Inalámbrico',
        'standard_selling_price': 80.0,
      });

      await db.insert('lots', {
        'id': 'lot_alm_low',
        'product_id': 'prod_low',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 3,
        'current_quantity': 3,
        'real_unit_cost': 40.0,
        'location': 'ALMACEN',
      });

      // Try transferring 5 units when only 3 are available
      final result = await transferStockToStoreUseCase(
        const TransferStockToStoreParams(
          productId: 'prod_low',
          quantity: 5,
        ),
      );

      expect(result.isLeft(), true);
    });
  });

  group('2. Lógica de Corrección / Reversión (RevertOrAdjustStoreStockUseCase)', () {
    test('Revertir lote de Tienda reintegra todo el stock a Almacén Central', () async {
      await db.insert('products', {
        'id': 'prod_rev',
        'sku': 'SKU-REV',
        'name': 'Teclado Mecánico RGB',
        'standard_selling_price': 350.0,
      });

      await db.insert('lots', {
        'id': 'lot_alm_rev',
        'product_id': 'prod_rev',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 10,
        'current_quantity': 6,
        'real_unit_cost': 200.0,
        'location': 'ALMACEN',
      });

      await db.insert('lots', {
        'id': 'lot_tienda_err',
        'product_id': 'prod_rev',
        'purchase_date': '2026-01-05T00:00:00.000Z',
        'initial_quantity': 4,
        'current_quantity': 4,
        'real_unit_cost': 200.0,
        'location': 'TIENDA',
      });

      // Admin revierte el lote cargado por error en Tienda
      final result = await revertOrAdjustStoreStockUseCase(
        const RevertOrAdjustStoreStockParams(lotId: 'lot_tienda_err', newQuantity: 0),
      );

      expect(result.isRight(), true);

      // Verify Tienda lot removed
      final tiendaLots = await db.query('lots', where: "id = 'lot_tienda_err'");
      expect(tiendaLots.isEmpty, true);

      // Verify Almacén lot replenished from 6 back to 10
      final almLots = await db.query('lots', where: "id = 'lot_alm_rev'");
      expect(almLots.first['current_quantity'], 10);
    });

    test('Corregir cantidad asignada en Tienda devuelve la diferencia a Almacén', () async {
      await db.insert('products', {
        'id': 'prod_adj',
        'sku': 'SKU-ADJ',
        'name': 'Monitor 27 Pulgadas IPS',
        'standard_selling_price': 1200.0,
      });

      await db.insert('lots', {
        'id': 'lot_alm_adj',
        'product_id': 'prod_adj',
        'purchase_date': '2026-01-01T00:00:00.000Z',
        'initial_quantity': 15,
        'current_quantity': 5,
        'real_unit_cost': 800.0,
        'location': 'ALMACEN',
      });

      await db.insert('lots', {
        'id': 'lot_tienda_adj',
        'product_id': 'prod_adj',
        'purchase_date': '2026-01-05T00:00:00.000Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 800.0,
        'location': 'TIENDA',
      });

      // Admin reduce la cantidad de 10 a 6 (4 vuelven a Almacén)
      final result = await revertOrAdjustStoreStockUseCase(
        const RevertOrAdjustStoreStockParams(lotId: 'lot_tienda_adj', newQuantity: 6),
      );

      expect(result.isRight(), true);

      final tiendaLot = await db.query('lots', where: "id = 'lot_tienda_adj'");
      expect(tiendaLot.first['current_quantity'], 6);

      final almLot = await db.query('lots', where: "id = 'lot_alm_adj'");
      expect(almLot.first['current_quantity'], 9); // 5 + 4 = 9
    });
  });

  group('3. Interfaz de Administración (AdminStoreInventoryScreen)', () {
    testWidgets('Muestra productos en Tienda, selector de vendedor y valida despacho en tiempo real', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed product and lots
      await tester.runAsync(() async {
        await db.insert('products', {
          'id': 'prod_screen_1',
          'sku': 'SKU-SC-01',
          'name': 'Calculadora Científica Plus',
          'brand': 'Casio',
          'standard_selling_price': 180.0,
        });
        await db.insert('lots', {
          'id': 'lot_screen_alm',
          'product_id': 'prod_screen_1',
          'purchase_date': '2026-01-01T00:00:00.000Z',
          'initial_quantity': 20,
          'current_quantity': 20,
          'real_unit_cost': 90.0,
          'location': 'ALMACEN',
        });
        await db.insert('lots', {
          'id': 'lot_screen_tnd',
          'product_id': 'prod_screen_1',
          'purchase_date': '2026-01-10T00:00:00.000Z',
          'initial_quantity': 5,
          'current_quantity': 5,
          'real_unit_cost': 90.0,
          'location': 'TIENDA',
        });

        await inventoryVm.loadProducts();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: mockAuth),
            ChangeNotifierProvider<InventoryViewModel>.value(value: inventoryVm),
          ],
          child: MaterialApp(
            home: AdminStoreInventoryScreen(
              viewModel: inventoryVm,
              sellers: [sellerUser],
            ),
          ),
        ),
      );
      await tester.pump();

      // Header and titles
      expect(find.text('Inventario en Tienda'), findsOneWidget);
      expect(find.text('Tienda / Vendedor Inspeccionado:'), findsOneWidget);

      // Product in Tienda is listed
      expect(find.text('Calculadora Científica Plus'), findsOneWidget);
      expect(find.text('SKU: SKU-SC-01 • Casio'), findsOneWidget);
      expect(find.text('5 uds.'), findsWidgets);

      // Open Dispatch Dialog via FAB
      await tester.tap(find.byKey(const Key('dispatch_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Despachar a Tienda'), findsWidgets);
      expect(find.text('Stock en Almacén:'), findsOneWidget);
      expect(find.text('20 uds.'), findsWidgets);

      // Test validation: input > 20
      await tester.enterText(find.byKey(const Key('dispatch_quantity_field')), '25');
      await tester.tap(find.byKey(const Key('dispatch_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No puede superar el stock en Almacén'), findsOneWidget);

      // Input valid: 4
      await tester.enterText(find.byKey(const Key('dispatch_quantity_field')), '4');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('dispatch_confirm_button')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Dialog closed and stock updated
      expect(find.text('Despachar a Tienda'), findsOneWidget); // Only FAB remaining
      expect(find.textContaining('Se transfirieron 4 uds.'), findsOneWidget);
    });
  });
}
