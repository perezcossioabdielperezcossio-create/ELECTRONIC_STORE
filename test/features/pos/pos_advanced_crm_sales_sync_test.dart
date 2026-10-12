import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/sync/data/models/sync_operation_model.dart';
import 'package:electronic_store/core/sync/data/datasources/sync_local_datasource.dart';
import 'package:electronic_store/core/sync/data/datasources/remote_sync_datasource.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import 'package:electronic_store/features/clients/data/datasources/client_local_datasource.dart';
import 'package:electronic_store/features/clients/data/repositories/client_repository_impl.dart';
import 'package:electronic_store/features/clients/domain/usecases/get_clients_usecase.dart';
import 'package:electronic_store/features/clients/domain/usecases/save_client_usecase.dart';
import 'package:electronic_store/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:electronic_store/features/pos/data/repositories/pos_repository_impl.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/pos/domain/usecases/create_sale.dart';
import 'package:electronic_store/features/pos/domain/usecases/void_sale_usecase.dart';
import 'package:electronic_store/features/pos/domain/usecases/get_sales_by_date.dart';
import 'package:electronic_store/features/pos/presentation/viewmodels/pos_viewmodel.dart';
import 'package:electronic_store/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:electronic_store/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:electronic_store/features/inventory/domain/usecases/get_all_products.dart';
import 'package:electronic_store/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:electronic_store/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'package:electronic_store/features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';

import 'package:electronic_store/features/deliveries/data/datasources/delivery_local_datasource.dart';
import 'package:electronic_store/features/deliveries/data/repositories/delivery_repository_impl.dart';
import 'package:electronic_store/features/deliveries/domain/usecases/get_deliveries_usecase.dart';
import 'package:electronic_store/features/deliveries/domain/usecases/save_delivery_usecase.dart';
import 'package:electronic_store/features/deliveries/domain/usecases/delete_delivery_usecase.dart';

class PosAdvancedFakeDbHelper implements DatabaseHelper {
  final Database db;
  PosAdvancedFakeDbHelper(this.db);
  
  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PosAdvancedFakeRemoteSyncDs implements RemoteSyncDataSource {
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
  Stream<List<Map<String, dynamic>>> listenToRemoteUsers() => const Stream.empty();

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
  late PosAdvancedFakeDbHelper dbHelper;
  late SyncLocalDataSourceImpl syncLocalDs;
  late PosAdvancedFakeRemoteSyncDs remoteSyncDs;
  late SyncManager syncManager;

  late ClientLocalDataSourceImpl clientLocalDs;
  late ClientRepositoryImpl clientRepo;
  late GetClientsUseCase getClientsUseCase;
  late SaveClientUseCase saveClientUseCase;

  late DeliveryLocalDataSourceImpl deliveryLocalDs;
  late DeliveryRepositoryImpl deliveryRepo;
  late GetDeliveriesUseCase getDeliveriesUseCase;
  late SaveDeliveryUseCase saveDeliveryUseCase;
  late DeleteDeliveryUseCase deleteDeliveryUseCase;

  late PosLocalDatasourceImpl posLocalDs;
  late PosRepositoryImpl posRepo;
  late CreateSale createSale;
  late VoidSaleUseCase voidSaleUseCase;
  late GetSalesByDate getSalesByDate;

  late InventoryLocalDataSourceImpl invLocalDs;
  late InventoryRepositoryImpl invRepo;
  late GetAllProducts getAllProducts;

  late DashboardLocalDatasourceImpl dashboardLocalDs;
  late DashboardRepositoryImpl dashboardRepo;
  late DashboardViewModel dashboardVm;

  late PosViewModel posVm;

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
            CREATE TABLE clientes (
                id TEXT PRIMARY KEY,
                nombre_alias TEXT NOT NULL,
                telefono_whatsapp TEXT,
                direccion_predet TEXT,
                creado_en TEXT DEFAULT (datetime('now'))
            );
          ''');
          await db.execute('''
            CREATE TABLE deliveries (
                id TEXT PRIMARY KEY,
                nombre TEXT NOT NULL,
                telefono TEXT NOT NULL,
                vehiculo TEXT,
                activo INTEGER DEFAULT 1,
                creado_en TEXT DEFAULT (datetime('now'))
            );
          ''');
          await db.execute('''
            CREATE TABLE customers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                created_at TEXT DEFAULT (datetime('now'))
            );
          ''');
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
            CREATE TABLE promoters (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT,
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
                status TEXT DEFAULT 'pending',
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
                lote_id TEXT,
                product_id TEXT NOT NULL,
                product_name TEXT NOT NULL,
                cantidad INTEGER,
                quantity INTEGER NOT NULL,
                costo_unitario_compra REAL,
                precio_unitario_cobrado REAL,
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

    dbHelper = PosAdvancedFakeDbHelper(db);
    syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
    remoteSyncDs = PosAdvancedFakeRemoteSyncDs();
    syncManager = SyncManager(
      localDataSource: syncLocalDs,
      remoteDataSource: remoteSyncDs,
    )..startRealtimeSync();

    clientLocalDs = ClientLocalDataSourceImpl(dbHelper: dbHelper);
    clientRepo = ClientRepositoryImpl(clientLocalDs);
    getClientsUseCase = GetClientsUseCase(clientRepo);
    saveClientUseCase = SaveClientUseCase(clientRepo);

    deliveryLocalDs = DeliveryLocalDataSourceImpl(dbHelper: dbHelper);
    deliveryRepo = DeliveryRepositoryImpl(deliveryLocalDs);
    getDeliveriesUseCase = GetDeliveriesUseCase(deliveryRepo);
    saveDeliveryUseCase = SaveDeliveryUseCase(deliveryRepo);
    deleteDeliveryUseCase = DeleteDeliveryUseCase(deliveryRepo);

    posLocalDs = PosLocalDatasourceImpl(dbHelper);
    posRepo = PosRepositoryImpl(posLocalDs);
    createSale = CreateSale(posRepo);
    voidSaleUseCase = VoidSaleUseCase(posRepo);
    getSalesByDate = GetSalesByDate(posRepo);

    invLocalDs = InventoryLocalDataSourceImpl(db);
    invRepo = InventoryRepositoryImpl(invLocalDs);
    getAllProducts = GetAllProducts(invRepo);

    dashboardLocalDs = DashboardLocalDatasourceImpl(dbHelper);
    dashboardRepo = DashboardRepositoryImpl(dashboardLocalDs);
    dashboardVm = DashboardViewModel(
      getFinancialOverview: GetFinancialOverviewUseCase(dashboardRepo),
      getDailyCashAudit: GetDailyCashAuditUseCase(dashboardRepo),
      getSalesByDate: getSalesByDate,
      syncManager: syncManager,
    );

    posVm = PosViewModel(
      createSale: createSale,
      getAllProducts: getAllProducts,
      voidSaleUseCase: voidSaleUseCase,
      getClientsUseCase: getClientsUseCase,
      saveClientUseCase: saveClientUseCase,
      getDeliveriesUseCase: getDeliveriesUseCase,
      saveDeliveryUseCase: saveDeliveryUseCase,
      deleteDeliveryUseCase: deleteDeliveryUseCase,
      syncManager: syncManager,
    );
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 30));
    syncManager.dispose();
    posVm.dispose();
    dashboardVm.dispose();
    remoteSyncDs.dispose();
    await db.close();
  });

  group('CRM: Persistencia Local y Sincronización de Clientes', () {
    test('Registrar nuevo cliente encola operación en sync_queue y persiste en SQLite', () async {
      final client = await posVm.createNewClient(
        nombreAlias: 'Carlos Tech',
        telefonoWhatsapp: '+591 71234567',
        direccionPredet: 'Calle Comercio #45',
      );

      expect(client, isNotNull);
      expect(client!.nombreAlias, 'Carlos Tech');

      // Verificar en SQLite tabla clientes
      final clientesDb = await db.query('clientes', where: 'id = ?', whereArgs: [client.id]);
      expect(clientesDb.length, 1);
      expect(clientesDb.first['nombre_alias'], 'Carlos Tech');
      expect(clientesDb.first['telefono_whatsapp'], '+591 71234567');
      expect(clientesDb.first['direccion_predet'], 'Calle Comercio #45');

      // Verificar en sync_queue
      final syncOps = await db.query('sync_queue', where: "table_name = 'clients'");
      expect(syncOps.isNotEmpty, true);
      final payload = jsonDecode(syncOps.first['payload'] as String);
      expect(payload['nombre_alias'], 'Carlos Tech');
      expect(payload['telefono_whatsapp'], '+591 71234567');
    });

    test('Snapshot remoto de clientes desde Firestore se inserta automáticamente en SQLite local', () async {
      await posVm.loadClients();
      expect(posVm.clients.length, 1); // Solo default "Cliente Mostrador"

      // Simular llegada de cliente remoto
      remoteSyncDs.clientsController.add([
        {
          'id': 'client_cloud_99',
          'nombre_alias': 'Distribuidora Norte',
          'telefono_whatsapp': '+591 78900000',
          'direccion_predet': 'Av. Blanco Galindo Km 5',
          'creado_en': DateTime.now().toIso8601String(),
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 100));

      final clientesDb = await db.query('clientes', where: 'id = ?', whereArgs: ['client_cloud_99']);
      expect(clientesDb.length, 1);
      expect(clientesDb.first['nombre_alias'], 'Distribuidora Norte');

      await posVm.loadClients();
      expect(posVm.clients.any((c) => c.id == 'client_cloud_99'), true);
    });
  });

  group('Ventas: FIFO Desglose Detallado, SQLite y Replicación', () {
    test('Venta con 2 lotes genera cabecera en ventas y desglose en detalle_ventas con consumo FIFO', () async {
      // 1. Crear producto con 2 lotes
      await db.insert('products', {
        'id': 'prod_auricular',
        'sku': 'SKU-HEADSET-PRO',
        'name': 'Auricular Gamer RGB',
        'brand': 'HyperX',
        'category': 'Audio',
        'standard_selling_price': 150.0,
        'min_stock_threshold': 2,
        'is_active': 1,
      });

      // Lote 1: 5 unidades a costo 70.0
      await db.insert('lots', {
        'id': 'lote_1',
        'product_id': 'prod_auricular',
        'purchase_date': '2026-01-01T00:00:00Z',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 70.0,
        'promoter_base_price': 120.0,
        'is_active': 1,
      });

      // Lote 2: 5 unidades a costo 80.0
      await db.insert('lots', {
        'id': 'lote_2',
        'product_id': 'prod_auricular',
        'purchase_date': '2026-02-01T00:00:00Z',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 80.0,
        'promoter_base_price': 120.0,
        'is_active': 1,
      });

      await posVm.loadProducts();

      // 2. Agregar 7 unidades al carrito con precio personalizado pactado Bs. 140.0
      final product = posVm.filteredProducts.firstWhere((p) => p.id == 'prod_auricular');
      expect(product.availableStock, 10);
      expect(product.promoterBasePrice, 120.0);

      posVm.addItem(
        const SaleItem(
          productId: 'prod_auricular',
          productName: 'Auricular Gamer RGB',
          quantity: 7,
          unitPrice: 140.0,
        ),
        product,
      );

      posVm.setPaymentMethod('TRANSFERENCIA');
      posVm.setDeliveryMethod('DELIVERY');
      posVm.setDeliveryFee(15.0);

      // 3. Ejecutar checkout
      final success = await posVm.checkout();
      expect(success, true);

      // 4. Verificar consumo FIFO en los lotes:
      // Lote 1 consumido completamente (5 - 5 = 0)
      final lote1 = (await db.query('lots', where: 'id = ?', whereArgs: ['lote_1'])).first;
      expect(lote1['current_quantity'], 0);

      // Lote 2 consumido parcialmente (5 - 2 = 3)
      final lote2 = (await db.query('lots', where: 'id = ?', whereArgs: ['lote_2'])).first;
      expect(lote2['current_quantity'], 3);

      // 5. Verificar cabecera en ventas
      final ventas = await db.query('ventas');
      expect(ventas.length, 1);
      final venta = ventas.first;
      expect(venta['metodo_pago'], 'TRANSFERENCIA');
      expect(venta['tipo_entrega'], 'DELIVERY');
      // Total: 7 * 140 + 15 = 995.0
      expect((venta['total_cobrado'] as num).toDouble(), 995.0);

      // 6. Verificar detalle_ventas (2 registros por el desglose FIFO de los 2 lotes)
      final detalles = await db.query('detalle_ventas', orderBy: 'costo_unitario_compra ASC');
      expect(detalles.length, 2);
      expect(detalles[0]['lote_id'], 'lote_1');
      expect(detalles[0]['cantidad'], 5);
      expect(detalles[0]['costo_unitario_compra'], 70.0);
      expect(detalles[0]['precio_unitario_cobrado'], 140.0);

      expect(detalles[1]['lote_id'], 'lote_2');
      expect(detalles[1]['cantidad'], 2);
      expect(detalles[1]['costo_unitario_compra'], 80.0);
      expect(detalles[1]['precio_unitario_cobrado'], 140.0);

      // 7. Verificar en sync_queue que se haya encolado la venta con el array completo de sale_details
      final salesSyncOps = await db.query('sync_queue', where: "table_name = 'sales'");
      expect(salesSyncOps.isNotEmpty, true);
      final salePayload = jsonDecode(salesSyncOps.first['payload'] as String);
      expect(salePayload['sale_details'], isA<List>());
      expect(salePayload['sale_details'].length, 2);
      expect(salePayload['sale_details'][0]['costo_unitario_compra'], 70.0);
      expect(salePayload['sale_details'][1]['costo_unitario_compra'], 80.0);
    });

    test('Recepción de venta remota de otro teléfono actualiza SQLite y Dashboard reactivamente', () async {
      await dashboardVm.loadDashboardData();
      expect(dashboardVm.dailySales.length, 0);

      // Simular venta que ocurrió en el teléfono 2
      final remoteSaleDate = DateTime.now().toIso8601String();
      remoteSyncDs.salesController.add([
        {
          'id': 'sale_remote_device_2',
          'cliente_id': 'mostrador',
          'customer_name': 'Cliente Tienda Física',
          'total_cobrado': 300.0,
          'metodo_pago': 'QR',
          'tipo_entrega': 'TIENDA',
          'fecha_venta': remoteSaleDate,
          'created_at': remoteSaleDate,
          'total': 300.0,
          'status': 'completed',
          'sale_details': [
            {
              'id': 'det_1',
              'venta_id': 'sale_remote_device_2',
              'lote_id': 'lote_x',
              'product_id': 'prod_x',
              'product_name': 'Teclado Mecánico',
              'cantidad': 1,
              'costo_unitario_compra': 180.0,
              'precio_unitario_cobrado': 300.0,
            }
          ],
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 120));

      // Verificar en SQLite local
      final ventas = await db.query('ventas', where: 'id = ?', whereArgs: ['sale_remote_device_2']);
      expect(ventas.length, 1);
      expect(ventas.first['metodo_pago'], 'QR');

      // Verificar que DashboardViewModel se haya reactivado y muestre la venta y las métricas
      await dashboardVm.loadDashboardData();
      expect(dashboardVm.dailySales.length, 1);
      expect(dashboardVm.dailySales.first.customerName, 'Cliente Tienda Física');
      expect(dashboardVm.dailySales.first.paymentMethod, 'QR');
      expect(dashboardVm.arqueoDiario?.ingresoBrutoTotal, 300.0);
      // Ganancia neta real = 300 - 180 = 120
      expect(dashboardVm.arqueoDiario?.gananciaNetaRealTotal, 120.0);
    });
  });

  group('Flexibilidad Comercial en POS: Búsqueda y Edición de Precios', () {
    test('Buscador rápido filtra por Nombre, SKU y Marca', () async {
      await db.insert('products', {
        'id': 'p1',
        'sku': 'SKU-APPLE-13',
        'name': 'iPhone 13',
        'brand': 'Apple',
        'category': 'Smartphones',
        'standard_selling_price': 800.0,
        'min_stock_threshold': 1,
        'is_active': 1,
      });

      await db.insert('products', {
        'id': 'p2',
        'sku': 'SKU-SAMS-S22',
        'name': 'Galaxy S22',
        'brand': 'Samsung',
        'category': 'Smartphones',
        'standard_selling_price': 700.0,
        'min_stock_threshold': 1,
        'is_active': 1,
      });

      await posVm.loadProducts();
      expect(posVm.filteredProducts.length, 2);

      // Búsqueda por SKU
      posVm.searchProducts('APPLE');
      expect(posVm.filteredProducts.length, 1);
      expect(posVm.filteredProducts.first.name, 'iPhone 13');

      // Búsqueda por Marca
      posVm.searchProducts('Samsung');
      expect(posVm.filteredProducts.length, 1);
      expect(posVm.filteredProducts.first.name, 'Galaxy S22');

      // Búsqueda por Nombre
      posVm.searchProducts('Galaxy');
      expect(posVm.filteredProducts.length, 1);
      expect(posVm.filteredProducts.first.sku, 'SKU-SAMS-S22');
    });

    test('Permitir editar precio unitario cobrado y recalcular total en tiempo real', () async {
      await db.insert('products', {
        'id': 'p3',
        'sku': 'SKU-MIC-1',
        'name': 'Micrófono USB',
        'brand': 'Fifine',
        'category': 'Audio',
        'standard_selling_price': 200.0,
        'min_stock_threshold': 1,
        'is_active': 1,
      });

      await db.insert('lots', {
        'id': 'lote_mic',
        'product_id': 'p3',
        'purchase_date': '2026-01-01T00:00:00Z',
        'initial_quantity': 10,
        'current_quantity': 10,
        'real_unit_cost': 100.0,
        'promoter_base_price': 160.0,
        'is_active': 1,
      });

      await posVm.loadProducts();
      final product = posVm.filteredProducts.first;

      posVm.addItem(
        const SaleItem(
          productId: 'p3',
          productName: 'Micrófono USB',
          quantity: 2,
          unitPrice: 200.0,
        ),
        product,
      );

      // Total inicial: 2 * 200 = 400
      expect(posVm.cartTotal, 400.0);

      // Aplicar rebaja pactada a Bs. 175.0 por unidad
      posVm.updateItemPrice('p3', 175.0);

      // Total recalculado en tiempo real: 2 * 175 = 350
      expect(posVm.cartTotal, 350.0);
    });
  });

  group('Deliveries / Repartidores: Persistencia Local, Sync y Asignación en POS', () {
    test('Registrar nuevo delivery encola operación en sync_queue y persiste en SQLite', () async {
      final delivery = await posVm.saveDelivery(
        nombre: 'Pedro Delivery Express',
        telefono: '+591 79998877',
        vehiculo: 'Moto Honda Wave',
      );

      expect(delivery, isNotNull);
      expect(delivery!.nombre, 'Pedro Delivery Express');
      expect(delivery.telefono, '+591 79998877');
      expect(delivery.vehiculo, 'Moto Honda Wave');
      expect(delivery.activo, isTrue);

      // Verificar persistencia en SQLite
      final rows = await db.query('deliveries', where: 'id = ?', whereArgs: [delivery.id]);
      expect(rows.length, 1);
      expect(rows.first['nombre'], 'Pedro Delivery Express');
      expect(rows.first['telefono'], '+591 79998877');
      expect(rows.first['vehiculo'], 'Moto Honda Wave');

      // Verificar que se encoló en sync_queue
      final syncQueue = await db.query('sync_queue', where: 'table_name = ?', whereArgs: ['deliveries']);
      expect(syncQueue.length, 1);
      final payload = jsonDecode(syncQueue.first['payload'] as String);
      expect(payload['id'], delivery.id);
      expect(payload['nombre'], 'Pedro Delivery Express');
    });

    test('Editar repartidor actualiza SQLite y encola mutación', () async {
      final delivery = await posVm.saveDelivery(
        nombre: 'Juan Moto',
        telefono: '+591 70001122',
        vehiculo: 'Moto Yamaha',
      );
      expect(delivery, isNotNull);

      // Editar
      final updated = await posVm.saveDelivery(
        id: delivery!.id,
        nombre: 'Juan Carlos Moto',
        telefono: '+591 70001122',
        vehiculo: 'Auto Suzuki',
      );

      expect(updated, isNotNull);
      expect(updated!.nombre, 'Juan Carlos Moto');
      expect(updated.vehiculo, 'Auto Suzuki');

      final rows = await db.query('deliveries', where: 'id = ?', whereArgs: [delivery.id]);
      expect(rows.first['nombre'], 'Juan Carlos Moto');
      expect(rows.first['vehiculo'], 'Auto Suzuki');
    });

    test('Eliminar repartidor actualiza SQLite y encola DELETE', () async {
      final delivery = await posVm.saveDelivery(
        nombre: 'Repartidor Temporal',
        telefono: '123456',
      );
      expect(delivery, isNotNull);

      await posVm.deleteDelivery(delivery!.id);

      final rows = await db.query('deliveries', where: 'id = ?', whereArgs: [delivery.id]);
      expect(rows.isEmpty, isTrue);

      final deleteOps = await db.query(
        'sync_queue',
        where: "table_name = 'deliveries' AND operation = 'DELETE'",
      );
      expect(deleteOps.length, 1);
      final payload = jsonDecode(deleteOps.first['payload'] as String);
      expect(payload['id'], delivery.id);
    });

    test('Sincronización reactiva bidireccional de Deliveries desde Firestore', () async {
      await posVm.loadDeliveries();
      expect(posVm.deliveries.isEmpty, isTrue);

      // Simular cambio remoto en Firestore de dos teléfonos conectados
      remoteSyncDs.deliveriesController.add([
        {
          'id': 'remote_deliv_1',
          'nombre': 'Delivery Remoto 1',
          'telefono': '+591 75554433',
          'vehiculo': 'Bicicleta Eléctrica',
          'activo': 1,
          'creado_en': DateTime.now().toIso8601String(),
        },
      ]);

      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que SQLite local se actualizó
      final rows = await db.query('deliveries', where: 'id = ?', whereArgs: ['remote_deliv_1']);
      expect(rows.length, 1);
      expect(rows.first['nombre'], 'Delivery Remoto 1');

      // Verificar que PosViewModel recargó los repartidores automáticamente
      expect(posVm.deliveries.any((d) => d.id == 'remote_deliv_1'), isTrue);
    });

    test('Venta con entrega a domicilio asigna delivery_id y delivery_name y los persiste en SQLite', () async {
      // 1. Crear producto con stock
      await db.insert('products', {
        'id': 'p_deliv',
        'sku': 'SKU-DELIV-1',
        'name': 'Auriculares Bluetooth',
        'standard_selling_price': 150.0,
        'min_stock_threshold': 2,
        'is_active': 1,
      });
      await db.insert('lots', {
        'id': 'lote_deliv',
        'product_id': 'p_deliv',
        'purchase_date': '2026-01-01T00:00:00Z',
        'initial_quantity': 5,
        'current_quantity': 5,
        'real_unit_cost': 80.0,
        'is_active': 1,
      });

      // 2. Crear delivery
      final delivery = await posVm.saveDelivery(
        nombre: 'Marcos Repartidor',
        telefono: '+591 76665544',
        vehiculo: 'Moto Suzuki',
      );
      expect(delivery, isNotNull);

      await posVm.loadProducts();
      final prod = posVm.filteredProducts.firstWhere((p) => p.id == 'p_deliv');

      posVm.addItem(
        const SaleItem(
          productId: 'p_deliv',
          productName: 'Auriculares Bluetooth',
          quantity: 1,
          unitPrice: 150.0,
        ),
        prod,
      );

      // 3. Configurar checkout con Delivery
      posVm.setPaymentMethod('EFECTIVO');
      posVm.setDeliveryMethod('DELIVERY');
      posVm.selectDelivery(delivery);
      posVm.setDeliveryFee(15.0);

      final success = await posVm.checkout();

      expect(success, isTrue);

      // 4. Verificar registro en tabla ventas
      final salesRows = await db.query('ventas', where: 'delivery_id = ?', whereArgs: [delivery!.id]);
      expect(salesRows.length, 1);
      final saleRecord = salesRows.first;
      expect(saleRecord['tipo_entrega'], 'DELIVERY');
      expect(saleRecord['delivery_id'], delivery.id);
      expect(saleRecord['delivery_name'], 'Marcos Repartidor');
      expect(saleRecord['delivery_fee'], 15.0);
      expect(saleRecord['total_cobrado'], 165.0);

      // 5. Verificar que la venta encolada en sync_queue incluye delivery_id y delivery_name
      final saleSync = await db.query('sync_queue', where: "table_name = 'sales'");
      expect(saleSync.isNotEmpty, isTrue);
      final matchingSaleSync = saleSync.firstWhere((s) {
        final payload = jsonDecode(s['payload'] as String);
        return payload['delivery_id'] == delivery.id;
      });
      final salePayload = jsonDecode(matchingSaleSync['payload'] as String);
      expect(salePayload['delivery_id'], delivery.id);
      expect(salePayload['delivery_name'], 'Marcos Repartidor');
    });
  });
}
