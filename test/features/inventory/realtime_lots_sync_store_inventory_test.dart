import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';

import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/sync/data/datasources/sync_local_datasource.dart';
import 'package:electronic_store/core/sync/data/datasources/remote_sync_datasource.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';
import 'package:electronic_store/features/inventory/domain/usecases/get_all_products.dart';
import 'package:electronic_store/features/inventory/domain/usecases/add_inventory_batch.dart';
import 'package:electronic_store/features/inventory/domain/usecases/consume_stock_fifo.dart';
import 'package:electronic_store/features/inventory/domain/usecases/create_product_with_lot_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/update_product_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/delete_product_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/transfer_stock_to_store_usecase.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/inventory/presentation/screens/inventory_catalog_screen.dart';

// Mocks
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
// ignore: subtype_of_sealed_class
class MockDocumentChange extends Mock implements DocumentChange<Map<String, dynamic>> {}
class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}
class MockInventoryViewModel extends Mock with ChangeNotifier implements InventoryViewModel {}

class RealtimeTestDbHelper implements DatabaseHelper {
  final Database _testDb;
  RealtimeTestDbHelper(this._testDb);

  @override
  Future<Database> get database async => _testDb;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late RealtimeTestDbHelper dbHelper;
  late InventoryLocalDataSourceImpl invLocalDs;
  late InventoryRepositoryImpl invRepo;
  late TransferStockToStoreUseCase transferStockToStoreUseCase;
  late CreateProductWithLotUseCase createProductWithLotUseCase;

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
              is_active INTEGER DEFAULT 1,
              FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
            );
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              table_name TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              status TEXT DEFAULT 'PENDING',
              retry_count INTEGER DEFAULT 0
            );
          ''');
        },
      ),
    );

    dbHelper = RealtimeTestDbHelper(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Persistencia y Herencia de Lotes en Firestore (lots)', () {
    test('Al transferir de Almacén a Tienda descuenta almacén en Firestore vía update y crea tienda vía set', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockLotsCol = MockCollectionReference();
      final mockAlmacenDoc = MockDocumentReference();
      final mockTiendaDoc = MockDocumentReference();

      when(() => mockFirestore.collection('lots')).thenReturn(mockLotsCol);
      when(() => mockLotsCol.doc('lot_alm_1')).thenReturn(mockAlmacenDoc);
      when(() => mockLotsCol.doc(any(that: isNot('lot_alm_1')))).thenReturn(mockTiendaDoc);

      Map<String, dynamic>? updatedAlmacenData;
      when(() => mockAlmacenDoc.update(any())).thenAnswer((inv) async {
        final arg = inv.positionalArguments[0];
        if (arg is Map) {
          updatedAlmacenData = Map<String, dynamic>.from(arg);
        }
      });

      Map<String, dynamic>? createdTiendaData;
      when(() => mockTiendaDoc.set(any(), any())).thenAnswer((inv) async {
        final arg = inv.positionalArguments[0];
        if (arg is Map) {
          createdTiendaData = Map<String, dynamic>.from(arg);
        }
      });

      invLocalDs = InventoryLocalDataSourceImpl(db, firestore: mockFirestore);
      invRepo = InventoryRepositoryImpl(invLocalDs);
      transferStockToStoreUseCase = TransferStockToStoreUseCase(invRepo);

      // Seed product and warehouse lot in SQLite
      await db.insert('products', {
        'id': 'prod_gamer_1',
        'sku': 'SKU-GAMER-1',
        'name': 'Mouse Gamer Pro',
        'brand': 'Logitech',
        'category': 'Periféricos',
        'standard_selling_price': 150.0,
      });

      await db.insert('lots', {
        'id': 'lot_alm_1',
        'product_id': 'prod_gamer_1',
        'purchase_date': '2026-02-01T10:00:00.000Z',
        'initial_quantity': 20,
        'current_quantity': 20,
        'real_unit_cost': 75.0,
        'promoter_base_price': 130.0,
        'location': 'ALMACEN',
        'is_active': 1,
      });

      // Execute transfer of 8 units to Tienda with custom unit price
      final result = await transferStockToStoreUseCase(
        const TransferStockToStoreParams(
          productId: 'prod_gamer_1',
          quantity: 8,
          sellerId: '70099888',
          storeLocation: 'TIENDA',
          unitPrice: 135.0,
        ),
      );

      expect(result.isRight(), true);

      // Verify Firestore warehouse lot was updated with remaining 12 units
      verify(() => mockAlmacenDoc.update(any())).called(1);
      expect(updatedAlmacenData, isNotNull);
      expect(updatedAlmacenData!['current_quantity'], 12);
      expect(updatedAlmacenData!['current_qty'], 12);

      // Verify Firestore store lot was created via set with exact JSON schema
      verify(() => mockTiendaDoc.set(any(), any())).called(1);
      expect(createdTiendaData, isNotNull);
      expect(createdTiendaData!['product_id'], 'prod_gamer_1');
      expect(createdTiendaData!['location'], 'TIENDA');
      expect(createdTiendaData!['current_qty'], 8);
      expect(createdTiendaData!['unit_cost'], 75.0);
      expect(createdTiendaData!['unit_price'], 135.0);
      expect(createdTiendaData!['updated_at'], isNotNull);

      // Verify SQLite local tables
      final almLots = await db.query('lots', where: "id = 'lot_alm_1'");
      expect(almLots.first['current_quantity'], 12);

      final tiendaLots = await db.query('lots', where: "location = 'TIENDA'");
      expect(tiendaLots.length, 1);
      expect(tiendaLots.first['current_quantity'], 8);
      expect(tiendaLots.first['real_unit_cost'], 75.0);
      expect(tiendaLots.first['promoter_base_price'], 135.0);

      // Verify offline sync_queue backup
      final syncQueueLots = await db.query('sync_queue', where: "table_name = 'lots'");
      expect(syncQueueLots.length, 2); // 1 UPDATE for warehouse, 1 CREATE for store
    });
  });

  group('2. Listener Reactivo en Tiempo Real (SyncManager)', () {
    test('Admin escucha todos los lotes y Seller filtra where location == TIENDA', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockLotsCol = MockCollectionReference();
      final mockFilteredQuery = MockQuery();

      final adminSnapshotsController = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      final sellerSnapshotsController = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      when(() => mockFirestore.collection('lots')).thenReturn(mockLotsCol);
      when(() => mockLotsCol.snapshots()).thenAnswer((_) => adminSnapshotsController.stream);
      when(() => mockLotsCol.where('location', isEqualTo: 'TIENDA')).thenReturn(mockFilteredQuery);
      when(() => mockFilteredQuery.snapshots()).thenAnswer((_) => sellerSnapshotsController.stream);

      final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
      final mockRemoteDs = MockRemoteSyncDataSource();

      final syncManager = SyncManager(
        localDataSource: syncLocalDs,
        remoteDataSource: mockRemoteDs,
        firestore: mockFirestore,
      );

      // 1. Admin configuration
      syncManager.configureUserSync(role: 'admin', celular: '77700000');
      verify(() => mockLotsCol.snapshots()).called(1);

      // 2. Seller configuration
      syncManager.configureUserSync(role: 'seller', celular: '70011223');
      verify(() => mockLotsCol.where('location', isEqualTo: 'TIENDA')).called(1);
      verify(() => mockFilteredQuery.snapshots()).called(1);

      syncManager.dispose();
      await adminSnapshotsController.close();
      await sellerSnapshotsController.close();
    });

    test('Replicación de DocumentChangeType (added, modified, removed) y notificación reactiva a InventoryViewModel', () async {
      final mockFirestore = MockFirebaseFirestore();
      final mockLotsCol = MockCollectionReference();
      final snapshotsController = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      when(() => mockFirestore.collection('lots')).thenReturn(mockLotsCol);
      when(() => mockLotsCol.snapshots()).thenAnswer((_) => snapshotsController.stream);

      // Pre-seed product
      await db.insert('products', {
        'id': 'prod_tablet_1',
        'sku': 'SKU-TAB-1',
        'name': 'Tablet Android 10"',
        'brand': 'Lenovo',
        'category': 'Tablets',
        'standard_selling_price': 1200.0,
      });

      final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
      final mockRemoteDs = MockRemoteSyncDataSource();
      invLocalDs = InventoryLocalDataSourceImpl(db, firestore: mockFirestore);
      invRepo = InventoryRepositoryImpl(invLocalDs);

      final syncManager = SyncManager(
        localDataSource: syncLocalDs,
        remoteDataSource: mockRemoteDs,
        firestore: mockFirestore,
      );

      final inventoryVm = InventoryViewModel(
        getAllProductsUseCase: GetAllProducts(invRepo),
        addLotUseCase: AddLotUseCase(invRepo),
        consumeStockUseCase: ConsumeStockFifo(invRepo),
        createProductWithLotUseCase: CreateProductWithLotUseCase(invRepo),
        updateProductUseCase: UpdateProductUseCase(invRepo),
        deleteProductUseCase: DeleteProductUseCase(invRepo),
        syncManager: syncManager,
      );

      await inventoryVm.loadProducts();
      expect(inventoryVm.products.first.availableStock, 0);

      syncManager.configureUserSync(role: 'admin', celular: '77711223');

      int notifiedCount = 0;
      inventoryVm.addListener(() {
        notifiedCount++;
      });

      // 1. Simulate DocumentChangeType.added
      final mockDocAdded = MockQueryDocumentSnapshot();
      when(() => mockDocAdded.id).thenReturn('lot_remote_10');
      when(() => mockDocAdded.data()).thenReturn({
        'id': 'lot_remote_10',
        'product_id': 'prod_tablet_1',
        'location': 'TIENDA',
        'current_qty': 15,
        'unit_cost': 800.0,
        'unit_price': 1150.0,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final mockChangeAdded = MockDocumentChange();
      when(() => mockChangeAdded.type).thenReturn(DocumentChangeType.added);
      when(() => mockChangeAdded.doc).thenReturn(mockDocAdded);

      final mockSnapshotAdded = MockQuerySnapshot();
      when(() => mockSnapshotAdded.docChanges).thenReturn([mockChangeAdded]);

      snapshotsController.add(mockSnapshotAdded);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify SQLite has the lot
      final localLotsAfterAdd = await db.query('lots', where: "id = 'lot_remote_10'");
      expect(localLotsAfterAdd.length, 1);
      expect(localLotsAfterAdd.first['current_quantity'], 15);
      expect(inventoryVm.products.first.stockInTienda, 15);
      expect(notifiedCount > 0, true);

      // 2. Simulate DocumentChangeType.modified
      final mockDocModified = MockQueryDocumentSnapshot();
      when(() => mockDocModified.id).thenReturn('lot_remote_10');
      when(() => mockDocModified.data()).thenReturn({
        'id': 'lot_remote_10',
        'product_id': 'prod_tablet_1',
        'location': 'TIENDA',
        'current_qty': 9,
        'unit_cost': 800.0,
        'unit_price': 1150.0,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final mockChangeModified = MockDocumentChange();
      when(() => mockChangeModified.type).thenReturn(DocumentChangeType.modified);
      when(() => mockChangeModified.doc).thenReturn(mockDocModified);

      final mockSnapshotModified = MockQuerySnapshot();
      when(() => mockSnapshotModified.docChanges).thenReturn([mockChangeModified]);

      snapshotsController.add(mockSnapshotModified);
      await Future.delayed(const Duration(milliseconds: 100));

      final localLotsAfterMod = await db.query('lots', where: "id = 'lot_remote_10'");
      expect(localLotsAfterMod.first['current_quantity'], 9);
      expect(inventoryVm.products.first.stockInTienda, 9);

      // 3. Simulate DocumentChangeType.removed
      final mockDocRemoved = MockQueryDocumentSnapshot();
      when(() => mockDocRemoved.id).thenReturn('lot_remote_10');
      when(() => mockDocRemoved.data()).thenReturn({});

      final mockChangeRemoved = MockDocumentChange();
      when(() => mockChangeRemoved.type).thenReturn(DocumentChangeType.removed);
      when(() => mockChangeRemoved.doc).thenReturn(mockDocRemoved);

      final mockSnapshotRemoved = MockQuerySnapshot();
      when(() => mockSnapshotRemoved.docChanges).thenReturn([mockChangeRemoved]);

      snapshotsController.add(mockSnapshotRemoved);
      await Future.delayed(const Duration(milliseconds: 100));

      final localLotsAfterRem = await db.query('lots', where: "id = 'lot_remote_10'");
      expect(localLotsAfterRem.isEmpty, true);
      expect(inventoryVm.products.first.stockInTienda, 0);

      inventoryVm.dispose();
      syncManager.dispose();
      await snapshotsController.close();
    });
  });

  group('3. Restricción Operativa para el Perfil Vendedor', () {
    test('Bloquea la creación de productos nuevos desde el perfil seller', () async {
      invLocalDs = InventoryLocalDataSourceImpl(db);
      invRepo = InventoryRepositoryImpl(invLocalDs);
      createProductWithLotUseCase = CreateProductWithLotUseCase(invRepo);

      final product = const Product(
        id: 'prod_seller_try',
        sku: 'SKU-TRY-1',
        name: 'Producto No Permitido',
        brand: 'Generic',
        category: 'Test',
        standardSellingPrice: 50.0,
        minStockThreshold: 1,
      );

      final lot = Lot(
        id: 'lot_try',
        productId: 'prod_seller_try',
        purchaseDate: DateTime.now(),
        initialQuantity: 5,
        currentQuantity: 5,
        realUnitCost: 20.0,
        location: 'TIENDA',
      );

      // Direct use case call with role seller must throw StateError
      expect(
        () => createProductWithLotUseCase(product: product, initialLot: lot, userRole: 'seller'),
        throwsA(isA<StateError>()),
      );

      // Through InventoryViewModel returns false and sets errorMessage
      final vm = InventoryViewModel(
        getAllProductsUseCase: GetAllProducts(invRepo),
        addLotUseCase: AddLotUseCase(invRepo),
        consumeStockUseCase: ConsumeStockFifo(invRepo),
        createProductWithLotUseCase: createProductWithLotUseCase,
        updateProductUseCase: UpdateProductUseCase(invRepo),
        deleteProductUseCase: DeleteProductUseCase(invRepo),
      );

      final success = await vm.createProductWithLot(product, lot, userRole: 'seller');
      expect(success, false);
      expect(vm.errorMessage, contains('perfil vendedor'));
    });

    testWidgets('Catálogo del vendedor solo lista productos con existencias en TIENDA y muestra precio asignado', (tester) async {
      final mockAuth = MockAuthViewModel();
      final sellerUser = UserModel(
        celular: '70012345',
        nombre: 'Carlos Vendedor',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal Central',
      );

      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);

      final productInTienda = Product(
        id: 'prod_tienda_active',
        sku: 'SKU-T1',
        name: 'Audífonos Bluetooth',
        brand: 'Sony',
        category: 'Audio',
        standardSellingPrice: 200.0,
        minStockThreshold: 1,
        lots: [
          Lot(
            id: 'l_t1',
            productId: 'prod_tienda_active',
            purchaseDate: DateTime(2026, 1, 1),
            initialQuantity: 10,
            currentQuantity: 10,
            realUnitCost: 100.0,
            promoterBasePrice: 160.0,
            location: 'TIENDA',
          ),
        ],
      );

      final productOnlyAlmacen = Product(
        id: 'prod_alm_only',
        sku: 'SKU-A1',
        name: 'Impresora Térmica Almacén',
        brand: 'Epson',
        category: 'Oficina',
        standardSellingPrice: 800.0,
        minStockThreshold: 1,
        lots: [
          Lot(
            id: 'l_a1',
            productId: 'prod_alm_only',
            purchaseDate: DateTime(2026, 1, 1),
            initialQuantity: 5,
            currentQuantity: 5,
            realUnitCost: 500.0,
            location: 'ALMACEN',
          ),
        ],
      );

      final mockInv = MockInventoryViewModel();
      when(() => mockInv.filteredProducts).thenReturn([productInTienda, productOnlyAlmacen]);
      when(() => mockInv.products).thenReturn([productInTienda, productOnlyAlmacen]);
      when(() => mockInv.state).thenReturn(ViewState.idle);
      when(() => mockInv.errorMessage).thenReturn(null);
      when(() => mockInv.filter).thenReturn(InventoryFilter.all);
      when(() => mockInv.totalCapitalInmovilizado).thenReturn(2500.0);
      when(() => mockInv.gananciaPotencialEstimada).thenReturn(3100.0);
      when(() => mockInv.loadProducts()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: mockAuth),
            ChangeNotifierProvider<InventoryViewModel>.value(value: mockInv),
          ],
          child: MaterialApp(
            home: InventoryCatalogScreen(viewModel: mockInv),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product in Tienda should be visible
      expect(find.text('Audífonos Bluetooth'), findsOneWidget);
      expect(find.text('Disponible en Tienda: 10'), findsOneWidget);

      // Product in Almacén ONLY must NOT be visible
      expect(find.text('Impresora Térmica Almacén'), findsNothing);

      // Must hide cost and wholesale price
      expect(find.textContaining('Mayorista: Bs.'), findsNothing);
      expect(find.textContaining('Último Costo:'), findsNothing);
      expect(find.textContaining('Capital Inmovilizado'), findsNothing);
    });
  });
}
