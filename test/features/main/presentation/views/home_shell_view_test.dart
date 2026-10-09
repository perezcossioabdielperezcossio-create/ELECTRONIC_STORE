import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:electronic_store/features/main/presentation/views/home_shell_view.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/pos/presentation/viewmodels/pos_viewmodel.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:electronic_store/features/promoters/presentation/viewmodels/promoters_viewmodel.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';

class MockInventoryViewModel extends Mock with ChangeNotifier implements InventoryViewModel {}
class MockPosViewModel extends Mock with ChangeNotifier implements PosViewModel {}
class MockDashboardViewModel extends Mock with ChangeNotifier implements DashboardViewModel {}
class MockPromotersViewModel extends Mock with ChangeNotifier implements PromotersViewModel {}
class MockSyncManager extends Mock with ChangeNotifier implements SyncManager {}
class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}

void main() {
  late MockInventoryViewModel mockInventoryVM;
  late MockPosViewModel mockPosVM;
  late MockDashboardViewModel mockDashboardVM;
  late MockPromotersViewModel mockPromotersVM;
  late MockSyncManager mockSyncManager;
  late MockAuthViewModel mockAuthVM;

  setUp(() {
    mockInventoryVM = MockInventoryViewModel();
    mockPosVM = MockPosViewModel();
    mockDashboardVM = MockDashboardViewModel();
    mockPromotersVM = MockPromotersViewModel();
    mockSyncManager = MockSyncManager();
    mockAuthVM = MockAuthViewModel();

    when(() => mockAuthVM.isAdmin).thenReturn(true);
    when(() => mockAuthVM.isSeller).thenReturn(false);
    when(() => mockAuthVM.currentUser).thenReturn(UserModel.masterAdmin1);
    when(() => mockAuthVM.isAuthenticated).thenReturn(true);

    when(() => mockSyncManager.isOnline).thenReturn(true);
    when(() => mockSyncManager.pendingCount).thenReturn(0);
    when(() => mockSyncManager.onRemoteDataChanged).thenAnswer((_) => const Stream.empty());

    when(() => mockInventoryVM.state).thenReturn(ViewState.idle);
    when(() => mockInventoryVM.filteredProducts).thenReturn([]);
    when(() => mockInventoryVM.totalCapitalInmovilizado).thenReturn(0.0);
    when(() => mockInventoryVM.gananciaPotencialEstimada).thenReturn(0.0);
    when(() => mockInventoryVM.filter).thenReturn(InventoryFilter.all);
    when(() => mockInventoryVM.loadProducts()).thenAnswer((_) async {});

    when(() => mockPosVM.filteredProducts).thenReturn([]);
    when(() => mockPosVM.isLoadingProducts).thenReturn(false);
    when(() => mockPosVM.error).thenReturn(null);
    when(() => mockPosVM.cart).thenReturn([]);
    when(() => mockPosVM.cartTotal).thenReturn(0.0);
    when(() => mockPosVM.clients).thenReturn([]);
    when(() => mockPosVM.selectedClient).thenReturn(null);
    when(() => mockPosVM.deliveries).thenReturn([]);
    when(() => mockPosVM.selectedDelivery).thenReturn(null);
    when(() => mockPosVM.loadProducts()).thenAnswer((_) async {});
    when(() => mockPosVM.loadClients()).thenAnswer((_) async {});
    when(() => mockPosVM.loadDeliveries()).thenAnswer((_) async {});

    when(() => mockDashboardVM.state).thenReturn(DashboardState.loaded);
    when(() => mockDashboardVM.overview).thenReturn(null);
    when(() => mockDashboardVM.arqueoDiario).thenReturn(null);
    when(() => mockDashboardVM.dailySales).thenReturn([]);
    when(() => mockDashboardVM.selectedDate).thenReturn(DateTime.now());
    when(() => mockDashboardVM.loadDashboardData()).thenAnswer((_) async {});
    when(() => mockDashboardVM.loadSellers()).thenAnswer((_) async {});
    when(() => mockDashboardVM.loadSellerDashboardData(any())).thenAnswer((_) async {});
    when(() => mockDashboardVM.isSellerLoading).thenReturn(false);
    when(() => mockDashboardVM.sellerErrorMessage).thenReturn(null);
    when(() => mockDashboardVM.sellerArqueo).thenReturn(null);
    when(() => mockDashboardVM.sellerSales).thenReturn([]);
    when(() => mockDashboardVM.sellerVentasHoy).thenReturn(0.0);
    when(() => mockDashboardVM.sellerVentasSemana).thenReturn(0.0);
    when(() => mockDashboardVM.adminFilter).thenReturn(AdminDashboardFilter.almacenCentral);
    when(() => mockDashboardVM.sellers).thenReturn([]);
    when(() => mockDashboardVM.selectedSellerPhone).thenReturn(null);

    when(() => mockPromotersVM.isLoading).thenReturn(false);
    when(() => mockPromotersVM.error).thenReturn(null);
    when(() => mockPromotersVM.promoters).thenReturn([]);
    when(() => mockPromotersVM.load()).thenAnswer((_) async {});
  });

  Widget buildShellWithProviders() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: mockAuthVM),
        ChangeNotifierProvider<SyncManager>.value(value: mockSyncManager),
        ChangeNotifierProvider<InventoryViewModel>.value(value: mockInventoryVM),
        ChangeNotifierProvider<PosViewModel>.value(value: mockPosVM),
        ChangeNotifierProvider<DashboardViewModel>.value(value: mockDashboardVM),
        ChangeNotifierProvider<PromotersViewModel>.value(value: mockPromotersVM),
      ],
      child: const MaterialApp(
        home: HomeShellView(),
      ),
    );
  }

  testWidgets('HomeShellView displays 4 navigation tabs for Admin (Inventario, POS, Dashboard, Promotores)', (tester) async {
    await tester.pumpWidget(buildShellWithProviders());
    await tester.pumpAndSettle();

    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Promotores'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    // Tap on Inventario tab
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    verify(() => mockInventoryVM.loadProducts()).called(greaterThanOrEqualTo(1));

    // Tap on Dashboard tab
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    verify(() => mockDashboardVM.loadDashboardData()).called(greaterThanOrEqualTo(1));

    // Tap on Promotores tab
    await tester.tap(find.text('Promotores'));
    await tester.pumpAndSettle();
    verify(() => mockPromotersVM.load()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('HomeShellView displays 3 navigation tabs for Seller (Catálogo, POS, Dashboard)', (tester) async {
    when(() => mockAuthVM.isAdmin).thenReturn(false);
    when(() => mockAuthVM.isSeller).thenReturn(true);
    when(() => mockAuthVM.currentUser).thenReturn(
      const UserModel(
        celular: '70012345',
        nombre: 'Vendedor Store',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal 1',
      ),
    );

    await tester.pumpWidget(buildShellWithProviders());
    await tester.pumpAndSettle();

    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Promotores'), findsNothing);
  });
}
