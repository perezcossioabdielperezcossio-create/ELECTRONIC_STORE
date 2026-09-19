import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/stock_status_badge.dart';

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
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
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
                const SizedBox(width: 8.0),
                ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) {
                    return FilterChip(
                      label: const Text('Reposición'),
                      selected: widget.viewModel.filter == InventoryFilter.lowStock || widget.viewModel.filter == InventoryFilter.outOfStock,
                      onSelected: (selected) {
                        widget.viewModel.setFilter(selected ? InventoryFilter.lowStock : InventoryFilter.all);
                      },
                      selectedColor: Colors.amber.shade200,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
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
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
