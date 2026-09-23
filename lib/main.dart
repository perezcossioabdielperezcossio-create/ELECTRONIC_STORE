import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/database_helper.dart';
import 'core/sync/data/datasources/sync_local_datasource.dart';
import 'core/sync/data/datasources/remote_sync_datasource.dart';
import 'core/sync/domain/services/sync_manager.dart';

import 'features/pos/data/datasources/pos_local_datasource.dart';
import 'features/pos/data/repositories/pos_repository_impl.dart';
import 'features/inventory/data/datasources/inventory_local_data_source.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';
import 'features/inventory/domain/usecases/get_all_products.dart';
import 'features/inventory/domain/usecases/add_inventory_batch.dart';
import 'features/inventory/domain/usecases/consume_stock_fifo.dart';
import 'features/inventory/domain/usecases/create_product_with_lot_usecase.dart';
import 'features/inventory/presentation/viewmodels/inventory_viewmodel.dart';

import 'features/pos/domain/usecases/create_sale.dart';
import 'features/pos/domain/usecases/void_sale_usecase.dart';
import 'features/pos/presentation/viewmodels/pos_viewmodel.dart';

import 'features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/usecases/get_financial_overview_usecase.dart';
import 'features/dashboard/domain/usecases/get_daily_cash_audit_usecase.dart';
import 'features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';

import 'features/main/presentation/views/home_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dbHelper = DatabaseHelper.instance;
  
  // Sync
  final syncLocalDs = SyncLocalDataSourceImpl(dbHelper: dbHelper);
  final remoteSyncDs = MockRemoteSyncDataSource();
  final syncManager = SyncManager(
    localDataSource: syncLocalDs, 
    remoteDataSource: remoteSyncDs,
  );
  
  // POS
  final posLocalDs = PosLocalDatasourceImpl(dbHelper);
  final posRepo = PosRepositoryImpl(posLocalDs);
  final createSale = CreateSale(posRepo);
  final voidSale = VoidSaleUseCase(posRepo);
  
  // Inventory
  final db = await dbHelper.database;
  final invLocalDs = InventoryLocalDataSourceImpl(db);
  final invRepo = InventoryRepositoryImpl(invLocalDs);
  final getAllProducts = GetAllProducts(invRepo);
  final addLotUseCase = AddLotUseCase(invRepo);
  final consumeStockFifo = ConsumeStockFifo(invRepo);
  final createProductWithLot = CreateProductWithLotUseCase(invRepo);

  // Dashboard
  final dashboardLocalDs = DashboardLocalDatasourceImpl(dbHelper);
  final dashboardRepo = DashboardRepositoryImpl(dashboardLocalDs);
  final getFinancialOverview = GetFinancialOverviewUseCase(dashboardRepo);
  final getDailyCashAudit = GetDailyCashAuditUseCase(dashboardRepo);

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
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PosViewModel(
            createSale: createSale,
            getAllProducts: getAllProducts,
            voidSaleUseCase: voidSale,
          )..loadProducts(), // Pre-load products on startup
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            getFinancialOverview: getFinancialOverview,
            getDailyCashAudit: getDailyCashAudit,
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
