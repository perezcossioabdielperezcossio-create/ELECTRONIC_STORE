import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/sync/data/models/sync_operation_model.dart';
import 'package:electronic_store/core/sync/data/datasources/sync_local_datasource.dart';
import 'package:electronic_store/core/sync/data/datasources/remote_sync_datasource.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:electronic_store/features/inventory/data/models/product_model.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/domain/usecases/get_all_products.dart';
import 'package:electronic_store/features/inventory/domain/usecases/add_inventory_batch.dart';
import 'package:electronic_store/features/inventory/domain/usecases/consume_stock_fifo.dart';
import 'package:electronic_store/features/inventory/domain/usecases/create_product_with_lot_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/update_product_usecase.dart';
import 'package:electronic_store/features/inventory/domain/usecases/delete_product_usecase.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'dart:async';

class FakeDatabaseHelper implements DatabaseHelper {
  final Database db;
  FakeDatabaseHelper(this.db);
  
  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRemoteSyncDataSource implements RemoteSyncDataSource {
  final StreamController<List<Map<String, dynamic>>> productsController = StreamController.broadcast();
  final StreamController<List<Map<String, dynamic>>> lotsController = StreamController.broadcast();
  final StreamController<List<Map<String, dynamic>>> salesController = StreamController.broadcast();
  final StreamController<List<Map<String, dynamic>>> clientsController = StreamController.broadcast();
  final StreamController<List<Map<String, dynamic>>> deliveriesController = StreamController.broadcast();

  final List<SyncOperationModel> pushedOperations = [];

  @override
  Future<SyncResult> syncOperation(SyncOperationModel operation) async {
    pushedOperations.add(operation);
    return SyncResult(success: true);
  }

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteProducts() => productsController.stream;

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteLots() => lotsController.stream;

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteSales() => salesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteClients() => clientsController.stream;

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteDeliveries() => deliveriesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges() => productsController.stream;

  void dispose() {
    productsController.close();
    lotsController.close();
    salesController.close();
    clientsController.close();
    deliveriesController.close();
  }
}

void main() {
  late Database db;
  late FakeDatabaseHelper dbHelper;
  late SyncLocalDataSourceImpl syncLocalDs;
  late FakeRemoteSyncDataSource fakeRemoteDs;
  late SyncManager syncManager;

  late InventoryLocalDataSourceImpl invLocalDs;
  late InventoryRepositoryImpl invRepo;
  late InventoryViewModel inventoryVm;

  late DashboardLocalDatasourceImpl dashboardLocalDs;
  late DashboardRepositoryImpl dashboardRepo;
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
            CREATE TABLE sales (
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
              is_locked INTEGER DEFAULT 0
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
              status TEXT DEFAULT 'PENDING',
              retry_count INTEGER DEFAULT 0
            );
          ''');
        },
      ),
    );

    dbHelper = FakeDatabaseHelper(db);
    syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
    fakeRemoteDs = FakeRemoteSyncDataSource();
    syncManager = SyncManager(
      localDataSource: syncLocalDs,
      remoteDataSource: fakeRemoteDs,
    )..startRealtimeSync();

    invLocalDs = InventoryLocalDataSourceImpl(db);
    invRepo = InventoryRepositoryImpl(invLocalDs);
    inventoryVm = InventoryViewModel(
      getAllProductsUseCase: GetAllProducts(invRepo),
      addLotUseCase: AddLotUseCase(invRepo),
      consumeStockUseCase: ConsumeStockFifo(invRepo),
      createProductWithLotUseCase: CreateProductWithLotUseCase(invRepo),
      updateProductUseCase: UpdateProductUseCase(invRepo),
      deleteProductUseCase: DeleteProductUseCase(invRepo),
      syncManager: syncManager,
    );

    dashboardLocalDs = DashboardLocalDatasourceImpl(dbHelper);
    dashboardRepo = DashboardRepositoryImpl(dashboardLocalDs);
    dashboardVm = DashboardViewModel(
      getFinancialOverview: GetFinancialOverviewUseCase(dashboardRepo),
      getDailyCashAudit: GetDailyCashAuditUseCase(dashboardRepo),
      syncManager: syncManager,
    );
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 50));
    syncManager.dispose();
    inventoryVm.dispose();
    dashboardVm.dispose();
    fakeRemoteDs.dispose();
    await db.close();
  });

  test('Local lot registration enqueues with Spanish and English aliases and triggers immediate sync', () async {
    // 1. Create a product first
    final product = ProductModel(
      id: 'prod_100',
      sku: 'SKU-PHONE-1',
      name: 'Smart Phone',
      brand: 'Xiaomi',
      category: 'Smartphones',
      standardSellingPrice: 300.0,
      minStockThreshold: 2,
    );

    final initialLot = Lot(
      id: 'lot_init',
      productId: 'prod_100',
      purchaseDate: DateTime.parse('2026-03-01T10:00:00Z'),
      initialQuantity: 5,
      currentQuantity: 5,
      realUnitCost: 200.0,
    );

    await inventoryVm.createProductWithLot(product, initialLot);

    // Verify sync_queue contains the lot with required payload fields
    final syncQueue = await db.query('sync_queue', where: "table_name = 'lots'");
    expect(syncQueue.isNotEmpty, true);
    final lotPayload = jsonDecode(syncQueue.first['payload'] as String);
    expect(lotPayload['productSku'], 'SKU-PHONE-1');
    expect(lotPayload['costo_unitario_real'], 200.0);
    expect(lotPayload['cantidad_actual'], 5);
    expect(lotPayload['fecha_ingreso'], '2026-03-01T10:00:00.000Z');
  });

  test('Remote lot snapshot from Firestore automatically updates SQLite, InventoryViewModel stock and DashboardViewModel Capital Inmovilizado', () async {
    // 1. Insert product locally first
    await db.insert('products', {
      'id': 'prod_remote_1',
      'sku': 'SKU-REMOTE-1',
      'name': 'Wireless Earbuds',
      'brand': 'Sony',
      'category': 'Audio',
      'standard_selling_price': 150.0,
      'min_stock_threshold': 5,
      'is_active': 1,
    });

    await inventoryVm.loadProducts();
    await dashboardVm.loadDashboardData();

    expect(inventoryVm.products.first.availableStock, 0);
    expect(dashboardVm.overview?.balancePatrimonial.capitalInmovilizado, 0.0);

    // 2. Simulate second device receiving new remote lot via Firestore snapshots
    fakeRemoteDs.lotsController.add([
      {
        'id': 'lot_remote_101',
        'product_id': 'prod_remote_1',
        'productSku': 'SKU-REMOTE-1',
        'cantidad_actual': 8,
        'costo_unitario_real': 90.0,
        'fecha_ingreso': '2026-03-02T12:00:00Z',
        'is_active': 1,
      }
    ]);

    // Give asynchronous stream listeners time to process
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. Verify SQLite has the new lot
    final lotsInDb = await db.query('lots', where: 'id = ?', whereArgs: ['lot_remote_101']);
    expect(lotsInDb.length, 1);
    expect(lotsInDb.first['current_quantity'], 8);
    expect(lotsInDb.first['real_unit_cost'], 90.0);

    // 4. Verify InventoryViewModel stock is reactively updated to 8
    expect(inventoryVm.products.first.availableStock, 8);
    expect(inventoryVm.products.first.totalInvestedCapital, 8 * 90.0);

    // 5. Verify DashboardViewModel Capital Inmovilizado is reactively recalculated to 8 * 90 = 720.0
    expect(dashboardVm.overview?.balancePatrimonial.capitalInmovilizado, 720.0);
    // Ganancia potencial: 8 * (150 - 90) = 480.0
    expect(dashboardVm.overview?.balancePatrimonial.gananciaPotencial, 480.0);
  });
}
