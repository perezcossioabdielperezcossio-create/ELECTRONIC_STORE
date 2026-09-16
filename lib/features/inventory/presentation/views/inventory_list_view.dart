import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/product_card.dart';

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
          return ListView.builder(
            itemCount: vm.products.length,
            itemBuilder: (_, i) => ProductCard(product: vm.products[i]),
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
