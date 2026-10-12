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
import 'package:electronic_store/features/inventory/presentation/screens/inventory_catalog_screen.dart';
import 'package:electronic_store/features/pos/domain/entities/sale.dart';
import 'package:electronic_store/features/pos/domain/entities/sale_item.dart';
import 'package:electronic_store/features/pos/presentation/viewmodels/pos_viewmodel.dart';
import 'package:electronic_store/features/pos/presentation/views/pos_sales_view.dart';
import 'package:electronic_store/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:electronic_store/features/dashboard/presentation/views/seller_dashboard_view.dart';
import 'package:electronic_store/features/dashboard/data/models/financial_metrics_model.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}
class MockInventoryViewModel extends Mock with ChangeNotifier implements InventoryViewModel {}
class MockPosViewModel extends Mock with ChangeNotifier implements PosViewModel {}
class MockDashboardViewModel extends Mock with ChangeNotifier implements DashboardViewModel {}

void main() {
  final productWithTiendaStock = Product(
    id: 'prod_tienda_1',
    sku: 'SKU-TIENDA-01',
    name: 'Calculadora Científica FX-991',
    brand: 'Casio',
    category: 'Oficina',
    standardSellingPrice: 150.0,
    minStockThreshold: 1,
    lots: [
      Lot(
        id: 'lot_t1',
        productId: 'prod_tienda_1',
        purchaseDate: DateTime(2026, 2, 1),
        initialQuantity: 5,
        currentQuantity: 5,
        realUnitCost: 80.0,
        location: 'TIENDA',
      ),
    ],
  );

  final productOnlyWarehouseStock = Product(
    id: 'prod_almacen_only',
    sku: 'SKU-ALMACEN-ONLY',
    name: 'Servidor Rack 1U Enterprise',
    brand: 'Dell',
    category: 'Servidores',
    standardSellingPrice: 8500.0,
    minStockThreshold: 1,
    lots: [
      Lot(
        id: 'lot_alm_1',
        productId: 'prod_almacen_only',
        purchaseDate: DateTime(2026, 1, 10),
        initialQuantity: 3,
        currentQuantity: 3,
        realUnitCost: 6000.0,
        location: 'ALMACEN',
      ),
    ],
  );

  final sellerUser = UserModel(
    celular: '70012345',
    nombre: 'Ana Vendedora',
    pin: '123456',
    role: UserRole.seller,
    tiendaNombre: 'Sucursal Central',
  );

  late MockAuthViewModel mockAuth;
  late MockInventoryViewModel mockInventory;
  late MockPosViewModel mockPos;
  late MockDashboardViewModel mockDashboard;

  setUp(() {
    mockAuth = MockAuthViewModel();
    mockInventory = MockInventoryViewModel();
    mockPos = MockPosViewModel();
    mockDashboard = MockDashboardViewModel();

    when(() => mockAuth.currentUser).thenReturn(sellerUser);
    when(() => mockAuth.isAdmin).thenReturn(false);
    when(() => mockAuth.isSeller).thenReturn(true);

    when(() => mockInventory.products).thenReturn([productWithTiendaStock, productOnlyWarehouseStock]);
    when(() => mockInventory.filteredProducts).thenReturn([productWithTiendaStock, productOnlyWarehouseStock]);
    when(() => mockInventory.state).thenReturn(ViewState.idle);
    when(() => mockInventory.errorMessage).thenReturn(null);
    when(() => mockInventory.filter).thenReturn(InventoryFilter.all);
    when(() => mockInventory.totalCapitalInmovilizado).thenReturn(18400.0);
    when(() => mockInventory.gananciaPotencialEstimada).thenReturn(7850.0);
    when(() => mockInventory.loadProducts()).thenAnswer((_) async {});

    when(() => mockPos.clients).thenReturn([PosViewModel.defaultClient]);
    when(() => mockPos.selectedClient).thenReturn(PosViewModel.defaultClient);
    when(() => mockPos.deliveries).thenReturn([]);
    when(() => mockPos.filteredProducts).thenReturn([productWithTiendaStock, productOnlyWarehouseStock]);
    when(() => mockPos.isLoadingProducts).thenReturn(false);
    when(() => mockPos.error).thenReturn(null);
    when(() => mockPos.cart).thenReturn([]);
    when(() => mockPos.cartTotal).thenReturn(0.0);
    when(() => mockPos.cartSubtotal).thenReturn(0.0);
    when(() => mockPos.violatesAntiLoss).thenReturn(false);
    when(() => mockPos.stockLocation).thenReturn('TIENDA');
    when(() => mockPos.getAvailableStock(productWithTiendaStock)).thenReturn(5);
    when(() => mockPos.getAvailableStock(productOnlyWarehouseStock)).thenReturn(0);
    when(() => mockPos.loadProducts()).thenAnswer((_) async {});
    when(() => mockPos.loadClients()).thenAnswer((_) async {});
    when(() => mockPos.loadDeliveries()).thenAnswer((_) async {});
    when(() => mockPos.refreshCatalog()).thenAnswer((_) async {});
    when(() => mockPos.setStockLocation(any())).thenReturn(null);
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

  group('1. Inventario del Vendedor - Stock Asignado en Tienda', () {
    testWidgets('Seller catalog only renders products with stockInTienda > 0 and hides warehouse-only products', (tester) async {
      await tester.pumpWidget(buildTestApp(child: InventoryCatalogScreen(viewModel: mockInventory)));
      await tester.pumpAndSettle();

      // Product with stockInTienda == 5 should be visible
      expect(find.text('Calculadora Científica FX-991'), findsOneWidget);
      expect(find.text('Disponible en Tienda: 5'), findsOneWidget);

      // Product with stockInTienda == 0 (only warehouse) should NOT be rendered in seller catalog
      expect(find.text('Servidor Rack 1U Enterprise'), findsNothing);

      // Verify privacy: capital inmovilizado and costs are hidden
      expect(find.textContaining('Capital Inmovilizado'), findsNothing);
      expect(find.textContaining('Ganancia Potencial'), findsNothing);
      expect(find.textContaining('Último Costo'), findsNothing);
    });
  });

  group('2. Venta Simplificada en POS (Perfil Vendedor)', () {
    testWidgets('POS displays client selector bar and filters out items with 0 stock in Tienda', (tester) async {
      await tester.pumpWidget(buildTestApp(child: const PosSalesView()));
      await tester.pumpAndSettle();

      // Client selector bar is visible
      expect(find.text('Cliente (Obligatorio):'), findsOneWidget);
      expect(find.text('Cliente Mostrador / Ocasional'), findsOneWidget);

      // Only items with available stock in TIENDA are displayed
      expect(find.text('Calculadora Científica FX-991'), findsOneWidget);
      expect(find.text('Servidor Rack 1U Enterprise'), findsNothing);

      // Tapping add opens dialog to register/edit unit price and quantity
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Agregar Calculadora Científica FX-991'), findsOneWidget);
      expect(find.text('Cantidad a Vender'), findsOneWidget);
      expect(find.text('Precio Unitario Cobrado (Bs.)'), findsOneWidget);
      expect(find.text('Agregar al Carrito'), findsOneWidget);
    });
  });

  group('3. Rediseño del SellerDashboardView', () {
    testWidgets('Displays Total Cobrado Hoy, Transacciones Concretadas, and Sale cards with required fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final saleDate = DateTime(2026, 10, 12, 16, 30);
      final testSale = Sale(
        id: 'sale_pos_seller_123',
        clienteId: 'cli_01',
        customerName: 'Juan Pérez',
        createdAt: saleDate,
        paymentMethod: 'EFECTIVO',
        storeLocation: 'TIENDA',
        usuarioId: sellerUser.celular,
        items: const [
          SaleItem(
            productId: 'prod_tienda_1',
            productName: 'Calculadora Científica FX-991',
            quantity: 2,
            unitPrice: 150.0,
          ),
        ],
      );

      when(() => mockDashboard.isSellerLoading).thenReturn(false);
      when(() => mockDashboard.sellerErrorMessage).thenReturn(null);
      when(() => mockDashboard.sellerArqueo).thenReturn(
        ArqueoDiario(
          fecha: saleDate,
          ingresoBrutoTotal: 300.0,
          capitalBaseRecuperadoTotal: 160.0,
          desglose: const [
            DesgloseMetodoPago(
              metodo: 'EFECTIVO',
              ingresoBruto: 300.0,
              capitalBaseRecuperado: 160.0,
            ),
          ],
        ),
      );
      when(() => mockDashboard.sellerVentasHoy).thenReturn(300.0);
      when(() => mockDashboard.sellerVentasSemana).thenReturn(1500.0);
      when(() => mockDashboard.selectedDate).thenReturn(saleDate);
      when(() => mockDashboard.sellerSales).thenReturn([testSale]);
      when(() => mockDashboard.loadSellerDashboardData(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestApp(child: const SellerDashboardView()));
      await tester.pumpAndSettle();

      // Encabezado / Resumen: Total Cobrado Hoy y Transacciones Concretadas
      expect(find.text('Total Cobrado Hoy'), findsOneWidget);
      expect(find.text('Transacciones Concretadas'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // 1 transacción

      // Confidential metrics MUST be hidden
      expect(find.textContaining('Capital Inmovilizado'), findsNothing);
      expect(find.textContaining('Ganancia Neta Real'), findsNothing);
      expect(find.textContaining('Costo de Adquisición'), findsNothing);
      expect(find.textContaining('Costo Real'), findsNothing);

      // Tarjeta de Venta Realizada: 4 Puntos Clave
      // 1. Monto / Precio final cobrado
      expect(find.textContaining('300.00'), findsWidgets);
      // 2. Nombre del Cliente
      expect(find.textContaining('Juan Pérez'), findsOneWidget);
      // 3. Fecha y hora de la venta (12/10/2026 16:30)
      expect(find.textContaining('12/10/2026 16:30'), findsOneWidget);
      // 4. Desglose de productos vendidos: Nombre y cantidad (ej. Calculadora x 2)
      expect(find.textContaining('Calculadora Científica FX-991 x 2'), findsOneWidget);
    });

    testWidgets('Fallbacks to Cliente Mostrador when sale has no customer name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final saleDate = DateTime(2026, 10, 12, 17, 00);
      final testSale = Sale(
        id: 'sale_pos_mostrador_999',
        clienteId: 'mostrador',
        customerName: null,
        createdAt: saleDate,
        paymentMethod: 'QR',
        storeLocation: 'TIENDA',
        usuarioId: sellerUser.celular,
        items: const [
          SaleItem(
            productId: 'prod_tienda_1',
            productName: 'Calculadora',
            quantity: 1,
            unitPrice: 150.0,
          ),
        ],
      );

      when(() => mockDashboard.isSellerLoading).thenReturn(false);
      when(() => mockDashboard.sellerErrorMessage).thenReturn(null);
      when(() => mockDashboard.sellerArqueo).thenReturn(null);
      when(() => mockDashboard.sellerVentasHoy).thenReturn(150.0);
      when(() => mockDashboard.sellerVentasSemana).thenReturn(150.0);
      when(() => mockDashboard.selectedDate).thenReturn(saleDate);
      when(() => mockDashboard.sellerSales).thenReturn([testSale]);
      when(() => mockDashboard.loadSellerDashboardData(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestApp(child: const SellerDashboardView()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cliente Mostrador'), findsOneWidget);
      expect(find.textContaining('Calculadora x 1'), findsOneWidget);
    });
  });
}
