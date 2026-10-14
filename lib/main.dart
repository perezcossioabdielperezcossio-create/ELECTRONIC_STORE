import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/database_helper.dart';
import 'core/sync/data/datasources/sync_local_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/sync/data/datasources/firestore_remote_data_source.dart';
import 'core/sync/domain/services/sync_manager.dart';

// Auth
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/get_current_session_usecase.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/register_seller_usecase.dart';
import 'features/auth/domain/usecases/seed_master_admins_usecase.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'features/auth/presentation/views/login_view.dart';

import 'features/clients/data/datasources/client_local_datasource.dart';
import 'features/clients/data/repositories/client_repository_impl.dart';
import 'features/clients/domain/usecases/get_clients_usecase.dart';
import 'features/clients/domain/usecases/save_client_usecase.dart';

import 'features/deliveries/data/datasources/delivery_local_datasource.dart';
import 'features/deliveries/data/repositories/delivery_repository_impl.dart';
import 'features/deliveries/domain/usecases/get_deliveries_usecase.dart';
import 'features/deliveries/domain/usecases/save_delivery_usecase.dart';
import 'features/deliveries/domain/usecases/delete_delivery_usecase.dart';

import 'features/promoters/data/datasources/promoter_local_datasource.dart';
import 'features/promoters/data/repositories/promoter_repository_impl.dart';
import 'features/promoters/domain/usecases/get_all_promoters.dart';
import 'features/promoters/presentation/viewmodels/promoters_viewmodel.dart';

import 'features/pos/data/datasources/pos_local_datasource.dart';
import 'features/pos/data/repositories/pos_repository_impl.dart';
import 'features/inventory/data/datasources/inventory_local_data_source.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';
import 'features/inventory/domain/usecases/get_all_products.dart';
import 'features/inventory/domain/usecases/add_inventory_batch.dart';
import 'features/inventory/domain/usecases/consume_stock_fifo.dart';
import 'features/inventory/domain/usecases/create_product_with_lot_usecase.dart';
import 'features/inventory/domain/usecases/update_product_usecase.dart';
import 'features/inventory/domain/usecases/delete_product_usecase.dart';
import 'features/inventory/domain/usecases/delete_lot_usecase.dart';
import 'features/inventory/domain/usecases/transfer_stock_to_store_usecase.dart';
import 'features/inventory/domain/usecases/revert_or_adjust_store_stock_usecase.dart';
import 'features/inventory/presentation/viewmodels/inventory_viewmodel.dart';

import 'features/pos/domain/usecases/create_sale.dart';
import 'features/pos/domain/usecases/void_sale_usecase.dart';
import 'features/pos/domain/usecases/get_sales_by_date.dart';
import 'features/pos/presentation/viewmodels/pos_viewmodel.dart';

import 'features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';

import 'features/main/presentation/views/home_shell_view.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase ya inicializado o aviso no crítico: $e');
  }
  
  final dbHelper = DatabaseHelper.instance;
  
  // Auth DataSources & UseCases
  final authLocalDs = AuthLocalDataSourceImpl(dbHelper: dbHelper);
  final authRemoteDs = AuthRemoteDataSourceImpl(firestore: FirebaseFirestore.instance);
  final authRepo = AuthRepositoryImpl(
    localDataSource: authLocalDs,
    remoteDataSource: authRemoteDs,
  );
  final loginUseCase = LoginUseCase(authRepo);
  final registerSellerUseCase = RegisterSellerUseCase(authRepo);
  final getCurrentSessionUseCase = GetCurrentSessionUseCase(authRepo);
  final logoutUseCase = LogoutUseCase(authRepo);
  final seedMasterAdminsUseCase = SeedMasterAdminsUseCase(authRepo);

  // Sync (Firestore Remote DataSource Real)
  final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
  final remoteSyncDs = FirestoreRemoteDataSource(firestore: FirebaseFirestore.instance);
  final syncManager = SyncManager(
    localDataSource: syncLocalDs, 
    remoteDataSource: remoteSyncDs,
  )..startRealtimeSync();
  
  // CRM / Clients
  final clientLocalDs = ClientLocalDataSourceImpl(dbHelper: dbHelper);
  final clientRepo = ClientRepositoryImpl(clientLocalDs);
  final getClients = GetClientsUseCase(clientRepo);
  final saveClient = SaveClientUseCase(clientRepo);

  // Deliveries / Repartidores
  final deliveryLocalDs = DeliveryLocalDataSourceImpl(dbHelper: dbHelper);
  final deliveryRepo = DeliveryRepositoryImpl(deliveryLocalDs);
  final getDeliveries = GetDeliveriesUseCase(deliveryRepo);
  final saveDelivery = SaveDeliveryUseCase(deliveryRepo);
  final deleteDelivery = DeleteDeliveryUseCase(deliveryRepo);

  // POS
  final posLocalDs = PosLocalDatasourceImpl(dbHelper);
  final posRepo = PosRepositoryImpl(posLocalDs);
  final createSale = CreateSale(posRepo);
  final voidSale = VoidSaleUseCase(posRepo);
  final getSalesByDate = GetSalesByDate(posRepo);
  
  // Inventory
  final db = await dbHelper.database;
  final invLocalDs = InventoryLocalDataSourceImpl(db);
  final invRepo = InventoryRepositoryImpl(invLocalDs);
  final getAllProducts = GetAllProducts(invRepo);
  final addLotUseCase = AddLotUseCase(invRepo);
  final consumeStockFifo = ConsumeStockFifo(invRepo);
  final createProductWithLot = CreateProductWithLotUseCase(invRepo);
  final updateProductUseCase = UpdateProductUseCase(invRepo);
  final deleteProductUseCase = DeleteProductUseCase(invRepo);
  final deleteLotUseCase = DeleteLotUseCase(invRepo);
  final transferStockToStore = TransferStockToStoreUseCase(invRepo);
  final revertOrAdjustStoreStock = RevertOrAdjustStoreStockUseCase(invRepo);

  // Dashboard
  final dashboardLocalDs = DashboardLocalDatasourceImpl(dbHelper);
  final dashboardRepo = DashboardRepositoryImpl(dashboardLocalDs);
  final getFinancialOverview = GetFinancialOverviewUseCase(dashboardRepo);
  final getDailyCashAudit = GetDailyCashAuditUseCase(dashboardRepo);

  // Promoters
  final promoterLocalDs = PromoterLocalDatasourceImpl(dbHelper);
  final promoterRepo = PromoterRepositoryImpl(promoterLocalDs);
  final getAllPromoters = GetAllPromoters(promoterRepo);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            loginUseCase: loginUseCase,
            registerSellerUseCase: registerSellerUseCase,
            getCurrentSessionUseCase: getCurrentSessionUseCase,
            logoutUseCase: logoutUseCase,
            seedMasterAdminsUseCase: seedMasterAdminsUseCase,
          )..initSession(),
        ),
        ChangeNotifierProvider.value(value: syncManager),
        ChangeNotifierProvider(
          create: (_) => InventoryViewModel(
            getAllProductsUseCase: getAllProducts,
            addLotUseCase: addLotUseCase,
            consumeStockUseCase: consumeStockFifo,
            createProductWithLotUseCase: createProductWithLot,
            updateProductUseCase: updateProductUseCase,
            deleteProductUseCase: deleteProductUseCase,
            deleteLotUseCase: deleteLotUseCase,
            transferStockToStoreUseCase: transferStockToStore,
            revertOrAdjustStoreStockUseCase: revertOrAdjustStoreStock,
            syncManager: syncManager,
          )..loadProducts(),
        ),
        ChangeNotifierProvider(
          create: (_) => PosViewModel(
            createSale: createSale,
            getAllProducts: getAllProducts,
            voidSaleUseCase: voidSale,
            getClientsUseCase: getClients,
            saveClientUseCase: saveClient,
            getDeliveriesUseCase: getDeliveries,
            saveDeliveryUseCase: saveDelivery,
            deleteDeliveryUseCase: deleteDelivery,
            syncManager: syncManager,
          )
            ..loadProducts()
            ..loadClients()
            ..loadDeliveries(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            getFinancialOverview: getFinancialOverview,
            getDailyCashAudit: getDailyCashAudit,
            getSalesByDate: getSalesByDate,
            syncManager: syncManager,
            dashboardRepository: dashboardRepo,
          )..loadDashboardData(),
        ),
        ChangeNotifierProvider(
          create: (_) => PromotersViewModel(
            getAll: getAllPromoters,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElectronicStore POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainAuthGate(),
    );
  }
}

class MainAuthGate extends StatelessWidget {
  const MainAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (auth.isAuthenticated) {
          return const HomeShellView();
        }

        return const LoginView();
      },
    );
  }
}
