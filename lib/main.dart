import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/database_helper.dart';
import 'core/sync/data/datasources/sync_local_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/sync/data/datasources/firestore_remote_data_source.dart';
import 'core/sync/domain/services/sync_manager.dart';

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
  
  // Sync (P-04: Firestore Remote DataSource Real)
  final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
  final remoteSyncDs = FirestoreRemoteDataSource(firestore: FirebaseFirestore.instance);
  final syncManager = SyncManager(
    localDataSource: syncLocalDs, 
    remoteDataSource: remoteSyncDs,
  )..startRealtimeSync();
  
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

  // Dashboard
  final dashboardLocalDs = DashboardLocalDatasourceImpl(dbHelper);
  final dashboardRepo = DashboardRepositoryImpl(dashboardLocalDs);
  final getFinancialOverview = GetFinancialOverviewUseCase(dashboardRepo);
  final getDailyCashAudit = GetDailyCashAuditUseCase(dashboardRepo);

  // Promoters (P-02)
  final promoterLocalDs = PromoterLocalDatasourceImpl(dbHelper);
  final promoterRepo = PromoterRepositoryImpl(promoterLocalDs);
  final getAllPromoters = GetAllPromoters(promoterRepo);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: syncManager),
        ChangeNotifierProvider(
          create: (_) => InventoryViewModel(
            getAllProductsUseCase: getAllProducts,
            addLotUseCase: addLotUseCase,
            consumeStockUseCase: consumeStockFifo,
            createProductWithLotUseCase: createProductWithLot,
            updateProductUseCase: updateProductUseCase,
            deleteProductUseCase: deleteProductUseCase,
            syncManager: syncManager,
          )..loadProducts(),
        ),
        ChangeNotifierProvider(
          create: (_) => PosViewModel(
            createSale: createSale,
            getAllProducts: getAllProducts,
            voidSaleUseCase: voidSale,
            syncManager: syncManager,
          )..loadProducts(), // Pre-load products on startup
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            getFinancialOverview: getFinancialOverview,
            getDailyCashAudit: getDailyCashAudit,
            getSalesByDate: getSalesByDate,
            syncManager: syncManager,
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
      home: const HomeShellView(),
    );
  }
}
