import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../pos/presentation/viewmodels/pos_viewmodel.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/product_card.dart';
import 'add_product_lot_sheet.dart';
import 'receive_stock_sheet.dart';

class InventoryCatalogScreen extends StatefulWidget {
  final InventoryViewModel viewModel;

  const InventoryCatalogScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<InventoryCatalogScreen> createState() => _InventoryCatalogScreenState();
}

class _InventoryCatalogScreenState extends State<InventoryCatalogScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    final bool isSeller = auth?.currentUser?.role == UserRole.seller || (auth?.isSeller ?? false);
    final bool isAdmin = !isSeller;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Catálogo de Inventario' : 'Catálogo de Productos'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isAdmin ? 130.0 : 65.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                if (isAdmin)
                  ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Colors.blue.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Capital Inmovilizado',
                                      style: TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${widget.viewModel.totalCapitalInmovilizado.toStringAsFixed(2)} Bs',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Card(
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Ganancia Potencial',
                                      style: TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${widget.viewModel.gananciaPotencialEstimada.toStringAsFixed(2)} Bs',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                if (isAdmin) const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por SKU o Nombre...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (value) {
                          widget.viewModel.setSearchQuery(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: widget.viewModel.filter == InventoryFilter.all,
                      onSelected: (selected) {
                        if (selected) widget.viewModel.setFilter(InventoryFilter.all);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Stock Bajo'),
                      selected: widget.viewModel.filter == InventoryFilter.lowStock,
                      onSelected: (selected) {
                        if (selected) widget.viewModel.setFilter(InventoryFilter.lowStock);
                      },
                      selectedColor: Colors.orange.shade200,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Agotados'),
                      selected: widget.viewModel.filter == InventoryFilter.outOfStock,
                      onSelected: (selected) {
                        if (selected) widget.viewModel.setFilter(InventoryFilter.outOfStock);
                      },
                      selectedColor: Colors.red.shade200,
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final invVm = context.read<InventoryViewModel>();
                final posVm = context.read<PosViewModel>();
                await invVm.loadProducts();
                await posVm.refreshCatalog();
              },
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  if (widget.viewModel.state == ViewState.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (widget.viewModel.state == ViewState.error) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              widget.viewModel.errorMessage ?? 'Error desconocido',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final products = widget.viewModel.filteredProducts;

                  if (products.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: const Center(
                            child: Text('No se encontraron productos.'),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(product: product);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isAdmin) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => AddProductLotSheet(viewModel: widget.viewModel),
            );
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ReceiveStockSheet(viewModel: widget.viewModel),
            );
          }
        },
        icon: Icon(isAdmin ? Icons.add : Icons.add_shopping_cart),
        label: Text(isAdmin ? 'Nuevo Producto' : 'Recibir Mercancía'),
      ),
    );
  }
}
