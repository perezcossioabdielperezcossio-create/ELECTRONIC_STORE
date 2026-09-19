import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';
import 'add_lot_dialog.dart';

class ProductDetailBottomSheet extends StatelessWidget {
  final String productId;

  const ProductDetailBottomSheet({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryViewModel>(
      builder: (context, vm, child) {
        try {
          final product = vm.products.firstWhere((p) => p.id == productId);
          return _buildContent(context, product);
        } catch (e) {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildContent(BuildContext context, Product product) {
    final formatter = NumberFormat.currency(symbol: 'Bs ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(16.0),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, 'Stock Total', '${product.availableStock}'),
              _buildStatItem(
                context, 
                'Último Costo', 
                product.latestCost != null ? formatter.format(product.latestCost) : 'N/A',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AddLotDialog(product: product),
              );
              // Si fue agregado, InventoryViewModel.loadProducts() ya fue llamado.
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('+ Agregar Lote / Compra'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text('Lotes Activos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: product.lots.where((l) => l.isActive).isEmpty
                ? const Center(child: Text('No hay lotes activos.'))
                : ListView.builder(
                    itemCount: product.lots.where((l) => l.isActive).length,
                    itemBuilder: (context, index) {
                      final activeLots = product.lots.where((l) => l.isActive).toList()
                        ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate)); // Recientes primero
                      final lot = activeLots[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('Stock: ${lot.currentQuantity} / ${lot.initialQuantity}'),
                          subtitle: Text('Ingreso: ${dateFormat.format(lot.purchaseDate)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Costo', style: TextStyle(fontSize: 10)),
                              Text(formatter.format(lot.realUnitCost), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
