import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/stock_status_badge.dart';
import 'add_product_lot_sheet.dart';
import 'add_lot_sheet.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Inventario'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
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
                                  const Text('Capital Inmovilizado', style: TextStyle(fontSize: 12)),
                                  Text('${widget.viewModel.totalCapitalInmovilizado.toStringAsFixed(2)} Bs', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                  const Text('Ganancia Potencial', style: TextStyle(fontSize: 12)),
                                  Text('${widget.viewModel.gananciaPotencialEstimada.toStringAsFixed(2)} Bs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 8.0),
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
            child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          if (widget.viewModel.state == ViewState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.viewModel.state == ViewState.error) {
            return Center(
              child: Text(
                widget.viewModel.errorMessage ?? 'Error desconocido',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final products = widget.viewModel.filteredProducts;

          if (products.isEmpty) {
            return const Center(
              child: Text('No se encontraron productos.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(product: product);
            },
          );
        },
      ),
    ),
  ],
),
floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddProductLotSheet(viewModel: widget.viewModel),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2.0,
      child: ExpansionTile(
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4.0),
            Text('SKU: ${product.sku}'),
            const SizedBox(height: 4.0),
            Row(
              children: [
                Text('Stock Total: ${product.availableStock}'),
                const Spacer(),
                StockStatusBadge(status: product.status),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              'Último Costo: ${product.latestCost != null ? '${product.latestCost!.toStringAsFixed(2)} Bs' : 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        children: [
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lotes Activos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...product.lots.where((lot) => lot.isActive).map((lot) {
            return ListTile(
              title: Text('Lote: ${lot.id} - Fecha: ${_formatDate(lot.purchaseDate)}'),
              subtitle: Text(
                'Restante: ${lot.currentQuantity} unid. | Costo: ${lot.realUnitCost.toStringAsFixed(2)} Bs',
              ),
            );
          }),
          if (product.lots.where((lot) => lot.isActive).isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No hay lotes activos para este producto.'),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddLotSheet(
                        viewModel: context.read<InventoryViewModel>(),
                        product: product,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Abastecer Lote'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
