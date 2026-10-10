import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pos/presentation/viewmodels/pos_viewmodel.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          final invVm = context.read<InventoryViewModel>();
          final posVm = context.read<PosViewModel>();
          await invVm.loadProducts();
          await posVm.refreshCatalog();
        },
        child: Consumer<InventoryViewModel>(
          builder: (context, vm, _) {
            if (vm.state == ViewState.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.state == ViewState.error) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(vm.errorMessage ?? 'Error desconocido')),
                  ),
                ),
              );
            }
            if (vm.products.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(child: Text('No hay productos.')),
                  ),
                ),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: vm.products.length,
              itemBuilder: (_, i) => ProductCard(product: vm.products[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {/* TODO: navegar a agregar producto */},
        child: const Icon(Icons.add),
      ),
    );
  }
}
