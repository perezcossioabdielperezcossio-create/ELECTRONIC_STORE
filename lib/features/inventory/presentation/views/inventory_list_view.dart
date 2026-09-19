import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/product_card.dart';

import '../widgets/product_detail_bottom_sheet.dart';

class InventoryListView extends StatefulWidget {
  const InventoryListView({super.key});

  @override
  State<InventoryListView> createState() => _InventoryListViewState();
}

class _InventoryListViewState extends State<InventoryListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryViewModel>().loadProducts();
    });
  }

  void _showProductDetail(BuildContext context, String productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ProductDetailBottomSheet(productId: productId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: Consumer<InventoryViewModel>(
        builder: (context, vm, _) {
          if (vm.state == ViewState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.state == ViewState.error) {
            return Center(child: Text(vm.errorMessage ?? 'Error desconocido'));
          }

          final products = vm.filteredProducts;

          return Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: vm.filter == InventoryFilter.all,
                        onSelected: (_) => vm.setFilter(InventoryFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Stock Bajo'),
                        selected: vm.filter == InventoryFilter.lowStock,
                        onSelected: (_) => vm.setFilter(InventoryFilter.lowStock),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Agotados'),
                        selected: vm.filter == InventoryFilter.outOfStock,
                        onSelected: (_) => vm.setFilter(InventoryFilter.outOfStock),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, i) => ProductCard(
                    product: products[i],
                    onTap: () => _showProductDetail(context, products[i].id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {/* TODO: navegar a agregar producto */},
        child: const Icon(Icons.add),
      ),
    );
  }
}
