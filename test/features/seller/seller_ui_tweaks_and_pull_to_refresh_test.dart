import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/inventory/presentation/widgets/product_card.dart';
import 'package:electronic_store/features/inventory/presentation/screens/inventory_catalog_screen.dart';
import 'package:electronic_store/features/inventory/presentation/screens/receive_stock_sheet.dart';
import 'package:electronic_store/features/inventory/presentation/views/inventory_list_view.dart';
import 'package:electronic_store/features/pos/presentation/viewmodels/pos_viewmodel.dart';
import 'package:electronic_store/features/pos/presentation/views/pos_sales_view.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:electronic_store/features/dashboard/presentation/views/seller_dashboard_view.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}
class MockInventoryViewModel extends Mock with ChangeNotifier implements InventoryViewModel {}
class MockPosViewModel extends Mock with ChangeNotifier implements PosViewModel {}
class MockDashboardViewModel extends Mock with ChangeNotifier implements DashboardViewModel {}

void main() {
  final sampleProduct = Product(
    id: 'prod_123',
    sku: 'SKU-TEST-01',
    name: 'Teclado Mecanico RGB',
    brand: 'Logitech',
    category: 'Perifericos',
    standardSellingPrice: 250.0,
    minStockThreshold: 2,
    lots: [
      Lot(
        id: 'lot_almacen_1',
        productId: 'prod_123',
        purchaseDate: DateTime(2026, 1, 1),
        initialQuantity: 10,
        currentQuantity: 10,
        realUnitCost: 120.0,
        promoterBasePrice: 180.0,
        location: 'ALMACEN',
      ),
      Lot(
        id: 'lot_tienda_1',
        productId: 'prod_123',
        purchaseDate: DateTime(2026, 1, 5),
        initialQuantity: 5,
        currentQuantity: 5,
        realUnitCost: 120.0,
        promoterBasePrice: 180.0,
        location: 'TIENDA',
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(
      Lot(
        id: 'fallback_lot',
        productId: 'fallback_prod',
        purchaseDate: DateTime.now(),
        initialQuantity: 1,
        currentQuantity: 1,
        realUnitCost: 10.0,
        location: 'TIENDA',
      ),
    );
    registerFallbackValue(sampleProduct);
  });

  late MockAuthViewModel mockAuth;
  late MockInventoryViewModel mockInventory;
  late MockPosViewModel mockPos;
  late MockDashboardViewModel mockDashboard;

  final sellerUser = UserModel(
    celular: '70011223',
    nombre: 'Vendedor Juan',
    pin: '123456',
    role: UserRole.seller,
    tiendaNombre: 'Sucursal Central',
  );

  final adminUser = UserModel(
    celular: '77799888',
    nombre: 'Admin Master',
    pin: '999888',
    role: UserRole.admin,
    tiendaNombre: 'Almacén Central',
  );

  setUp(() {
    mockAuth = MockAuthViewModel();
    mockInventory = MockInventoryViewModel();
    mockPos = MockPosViewModel();
    mockDashboard = MockDashboardViewModel();

    when(() => mockInventory.products).thenReturn([sampleProduct]);
    when(() => mockInventory.filteredProducts).thenReturn([sampleProduct]);
    when(() => mockInventory.state).thenReturn(ViewState.idle);
    when(() => mockInventory.errorMessage).thenReturn(null);
    when(() => mockInventory.filter).thenReturn(InventoryFilter.all);
    when(() => mockInventory.totalCapitalInmovilizado).thenReturn(1800.0);
    when(() => mockInventory.gananciaPotencialEstimada).thenReturn(1950.0);
    when(() => mockInventory.loadProducts()).thenAnswer((_) async {});

    when(() => mockPos.filteredProducts).thenReturn([sampleProduct]);
    when(() => mockPos.isLoadingProducts).thenReturn(false);
    when(() => mockPos.error).thenReturn(null);
    when(() => mockPos.cart).thenReturn([]);
    when(() => mockPos.stockLocation).thenReturn('TIENDA');
    when(() => mockPos.getAvailableStock(any())).thenReturn(5);
    when(() => mockPos.loadProducts()).thenAnswer((_) async {});
    when(() => mockPos.loadClients()).thenAnswer((_) async {});
    when(() => mockPos.loadDeliveries()).thenAnswer((_) async {});
    when(() => mockPos.refreshCatalog()).thenAnswer((_) async {});
    when(() => mockPos.setStockLocation(any())).thenReturn(null);

    when(() => mockDashboard.isSellerLoading).thenReturn(false);
    when(() => mockDashboard.sellerErrorMessage).thenReturn(null);
    when(() => mockDashboard.sellerArqueo).thenReturn(null);
    when(() => mockDashboard.sellerVentasHoy).thenReturn(500.0);
    when(() => mockDashboard.sellerVentasSemana).thenReturn(2500.0);
    when(() => mockDashboard.selectedDate).thenReturn(DateTime.now());
    when(() => mockDashboard.sellerSales).thenReturn([]);
    when(() => mockDashboard.loadSellerDashboardData(any())).thenAnswer((_) async {});
  });

  Widget buildTestApp({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: mockAuth),
        ChangeNotifierProvider<InventoryViewModel>.value(value: mockInventory),
        ChangeNotifierProvider<PosViewModel>.value(value: mockPos),
        ChangeNotifierProvider<DashboardViewModel>.value(value: mockDashboard),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('1. Ocultar Precios Mayoristas al Perfil Vendedor', () {
    testWidgets('ProductCard hides wholesale price and cost when user is Seller', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);

      await tester.pumpWidget(buildTestApp(child: ProductCard(product: sampleProduct)));
      await tester.pumpAndSettle();

      // Debería ver el precio estándar
      expect(find.text('Estándar: Bs. 250.00'), findsOneWidget);
      // NO debe ver el precio mayorista
      expect(find.textContaining('Mayorista: Bs.'), findsNothing);
      // NO debe ver el costo unitario
      expect(find.textContaining('Último Costo:'), findsNothing);
      // Debe ver su botón de recibir mercancía
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    });

    testWidgets('ProductCard displays wholesale price and cost when user is Admin', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(adminUser);
      when(() => mockAuth.isAdmin).thenReturn(true);
      when(() => mockAuth.isSeller).thenReturn(false);

      await tester.pumpWidget(buildTestApp(child: ProductCard(product: sampleProduct)));
      await tester.pumpAndSettle();

      // Admin ve tanto Estándar como Mayorista y Costo
      expect(find.text('Estándar: Bs. 250.00'), findsOneWidget);
      expect(find.text('Mayorista: Bs. 180.00'), findsOneWidget);
      expect(find.textContaining('Último Costo:'), findsOneWidget);
      // Admin ve el menú desplegable con opciones de admin
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('PosSalesView hides wholesale price badges when user is Seller', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);

      await tester.pumpWidget(buildTestApp(child: const PosSalesView()));
      await tester.pumpAndSettle();

      // Verifica que el precio estándar está presente
      expect(find.text('Estándar: Bs. 250.00'), findsOneWidget);
      // Verifica que la etiqueta Mayorista NO se muestra para vendedor
      expect(find.textContaining('Mayorista: Bs.'), findsNothing);
    });

    testWidgets('PosSalesView displays wholesale price badge when user is Admin', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(adminUser);
      when(() => mockAuth.isAdmin).thenReturn(true);
      when(() => mockAuth.isSeller).thenReturn(false);

      await tester.pumpWidget(buildTestApp(child: const PosSalesView()));
      await tester.pumpAndSettle();

      expect(find.text('Estándar: Bs. 250.00'), findsOneWidget);
      expect(find.text('Mayorista: Bs. 180.00'), findsOneWidget);
    });
  });

  group('2. Flujo de Ingreso de Inventario para Tienda (Heredar Códigos, sin crear productos)', () {
    testWidgets('InventoryCatalogScreen shows "Recibir Mercancía" and NO new product creation for Seller', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);
      when(() => mockAuth.isSeller).thenReturn(true);

      await tester.pumpWidget(buildTestApp(child: InventoryCatalogScreen(viewModel: mockInventory)));
      await tester.pumpAndSettle();

      // Botón flotante para vendedor es Recibir Mercancía
      expect(find.text('Recibir Mercancía'), findsOneWidget);
      expect(find.text('Nuevo Producto'), findsNothing);
    });

    testWidgets('InventoryCatalogScreen shows "Nuevo Producto" for Admin', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(adminUser);
      when(() => mockAuth.isAdmin).thenReturn(true);
      when(() => mockAuth.isSeller).thenReturn(false);

      await tester.pumpWidget(buildTestApp(child: InventoryCatalogScreen(viewModel: mockInventory)));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Producto'), findsOneWidget);
    });

    testWidgets('ReceiveStockSheet validates quantity, creates lot with TIENDA location and inherits cost', (tester) async {
      when(() => mockInventory.addLot(any(), any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: ReceiveStockSheet(
              viewModel: mockInventory,
              initialProduct: sampleProduct,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica campos visibles: no hay campos para SKU, nombre o marca
      expect(find.text('Recibir Mercancía / Cargar Stock'), findsOneWidget);
      expect(find.textContaining('SKU: SKU-TEST-01'), findsOneWidget);
      expect(find.text('Cantidad Recibida'), findsOneWidget);
      expect(find.text('Nuevo SKU'), findsNothing);

      // Ingresar cantidad
      final qtyInput = find.byType(TextFormField);
      await tester.enterText(qtyInput, '8');

      // Presionar confirmación
      await tester.tap(find.text('Cargar Stock a Tienda'));
      await tester.pumpAndSettle();

      // Verificar que se invocó addLot con location TIENDA y costo heredado
      verify(() => mockInventory.addLot(
        sampleProduct.id,
        any(
          that: isA<Lot>()
              .having((l) => l.location, 'location', 'TIENDA')
              .having((l) => l.initialQuantity, 'initialQuantity', 8)
              .having((l) => l.currentQuantity, 'currentQuantity', 8)
              .having((l) => l.realUnitCost, 'realUnitCost', 120.0)
              .having((l) => l.promoterBasePrice, 'promoterBasePrice', 180.0),
        ),
      )).called(1);
    });
  });

  group('3. Recarga Manual con Gesto (Pull-to-Refresh)', () {
    testWidgets('PosSalesView contains RefreshIndicator and calls loadProducts and refreshCatalog on refresh', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(buildTestApp(child: const PosSalesView()));
      await tester.pumpAndSettle();

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);

      // Deslizar para refrescar
      await tester.fling(find.byType(ListView), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockInventory.loadProducts()).called(greaterThanOrEqualTo(1));
      verify(() => mockPos.refreshCatalog()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('InventoryCatalogScreen contains RefreshIndicator and triggers refresh', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);
      when(() => mockAuth.isAdmin).thenReturn(false);

      await tester.pumpWidget(buildTestApp(child: InventoryCatalogScreen(viewModel: mockInventory)));
      await tester.pumpAndSettle();

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockInventory.loadProducts()).called(greaterThanOrEqualTo(1));
      verify(() => mockPos.refreshCatalog()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('InventoryListView contains RefreshIndicator and triggers refresh', (tester) async {
      await tester.pumpWidget(buildTestApp(child: const InventoryListView()));
      await tester.pumpAndSettle();

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockInventory.loadProducts()).called(greaterThanOrEqualTo(1));
      verify(() => mockPos.refreshCatalog()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('SellerDashboardView contains RefreshIndicator and triggers reload of data, inventory and pos', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sellerUser);

      await tester.pumpWidget(buildTestApp(child: const SellerDashboardView()));
      await tester.pumpAndSettle();

      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockDashboard.loadSellerDashboardData(sellerUser.celular)).called(greaterThanOrEqualTo(1));
      verify(() => mockInventory.loadProducts()).called(greaterThanOrEqualTo(1));
      verify(() => mockPos.refreshCatalog()).called(greaterThanOrEqualTo(1));
    });
  });
}
