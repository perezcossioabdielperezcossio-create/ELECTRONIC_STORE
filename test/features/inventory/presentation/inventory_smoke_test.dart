import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:electronic_store/features/inventory/presentation/screens/inventory_catalog_screen.dart';
import 'package:electronic_store/features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';
import 'package:electronic_store/features/inventory/presentation/screens/add_product_lot_sheet.dart';
import 'package:mocktail/mocktail.dart';

class MockInventoryViewModel extends Mock with ChangeNotifier implements InventoryViewModel {}

void main() {
  late MockInventoryViewModel mockViewModel;

  setUp(() {
    mockViewModel = MockInventoryViewModel();
    when(() => mockViewModel.state).thenReturn(ViewState.idle);
    when(() => mockViewModel.filteredProducts).thenReturn([
      Product(
        id: '1', sku: 'SKU1', name: 'Product 1', brand: 'B', category: 'C',
        standardSellingPrice: 10, minStockThreshold: 5,
      )
    ]);
    when(() => mockViewModel.totalCapitalInmovilizado).thenReturn(100.0);
    when(() => mockViewModel.gananciaPotencialEstimada).thenReturn(50.0);
    when(() => mockViewModel.filter).thenReturn(InventoryFilter.all);
    when(() => mockViewModel.errorMessage).thenReturn(null);
    when(() => mockViewModel.loadProducts()).thenAnswer((_) async {});
  });

  testWidgets('InventoryCatalogScreen smoke test: renderiza y muestra modal sin excepciones', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<InventoryViewModel>.value(
          value: mockViewModel,
          child: Builder(
            builder: (context) {
              return InventoryCatalogScreen(viewModel: context.read<InventoryViewModel>());
            }
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Catálogo de Inventario'), findsOneWidget);
    
    // Verify product list renders the mock product
    expect(find.text('Product 1'), findsOneWidget);
    
    // Verify FAB
    final fab = find.byIcon(Icons.add);
    expect(fab, findsOneWidget);

    // Simulate tap on FAB to add product
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify bottom sheet opened
    expect(find.byType(AddProductLotSheet), findsOneWidget);
  });
}
