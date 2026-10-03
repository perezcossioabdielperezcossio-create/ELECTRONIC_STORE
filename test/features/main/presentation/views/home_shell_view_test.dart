import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:electronic_store/features/main/presentation/views/home_shell_view.dart';
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

void main() {
  late MockInventoryViewModel mockInventoryVM;
  late MockPosViewModel mockPosVM;
  late MockDashboardViewModel mockDashboardVM;
  late MockPromotersViewModel mockPromotersVM;
  late MockSyncManager mockSyncManager;

  setUp(() {
    mockInventoryVM = MockInventoryViewModel();
    mockPosVM = MockPosViewModel();
    mockDashboardVM = MockDashboardViewModel();
    mockPromotersVM = MockPromotersViewModel();
    mockSyncManager = MockSyncManager();

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
    when(() => mockPosVM.loadProducts()).thenAnswer((_) async {});

    when(() => mockDashboardVM.state).thenReturn(DashboardState.loaded);
    when(() => mockDashboardVM.overview).thenReturn(null);
    when(() => mockDashboardVM.arqueoDiario).thenReturn(null);
    when(() => mockDashboardVM.dailySales).thenReturn([]);
    when(() => mockDashboardVM.selectedDate).thenReturn(DateTime.now());
    when(() => mockDashboardVM.loadDashboardData()).thenAnswer((_) async {});

    when(() => mockPromotersVM.isLoading).thenReturn(false);
    when(() => mockPromotersVM.error).thenReturn(null);
    when(() => mockPromotersVM.promoters).thenReturn([]);
    when(() => mockPromotersVM.load()).thenAnswer((_) async {});
  });

  testWidgets('HomeShellView displays 4 navigation tabs (Inventario, POS, Dashboard, Promotores)', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncManager>.value(value: mockSyncManager),
          ChangeNotifierProvider<InventoryViewModel>.value(value: mockInventoryVM),
          ChangeNotifierProvider<PosViewModel>.value(value: mockPosVM),
          ChangeNotifierProvider<DashboardViewModel>.value(value: mockDashboardVM),
          ChangeNotifierProvider<PromotersViewModel>.value(value: mockPromotersVM),
        ],
        child: const MaterialApp(
          home: HomeShellView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Promotores'), findsOneWidget);

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
}
