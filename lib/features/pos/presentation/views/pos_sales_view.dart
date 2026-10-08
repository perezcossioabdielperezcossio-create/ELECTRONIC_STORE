import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/pos_viewmodel.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../../domain/entities/sale_item.dart';
import '../../../inventory/domain/entities/product.dart';

import '../../../deliveries/presentation/widgets/delivery_management_dialog.dart';

class PosSalesView extends StatefulWidget {
  const PosSalesView({super.key});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

class _PosSalesViewState extends State<PosSalesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel?>();
      final posVm = context.read<PosViewModel>();
      if (auth != null && !auth.isAdmin) {
        posVm.setStockLocation('TIENDA');
      }
      posVm.loadProducts();
      posVm.loadClients();
      posVm.loadDeliveries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomPriceDialog(BuildContext context, Product product, PosViewModel vm) {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: product.standardSellingPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Agregar ${product.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SKU: ${product.sku} | Marca: ${product.brand}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.sell, size: 16),
                    label: Text('Estándar: Bs. ${product.standardSellingPrice.toStringAsFixed(2)}'),
                    onPressed: () {
                      priceController.text = product.standardSellingPrice.toStringAsFixed(2);
                    },
                  ),
                  if (product.promoterBasePrice != null)
                    ActionChip(
                      avatar: const Icon(Icons.storefront, size: 16, color: Colors.amber),
                      label: Text('Mayorista: Bs. ${product.promoterBasePrice!.toStringAsFixed(2)}'),
                      onPressed: () {
                        priceController.text = product.promoterBasePrice!.toStringAsFixed(2);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a Vender',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio Unitario Cobrado (Bs.)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on),
                  prefixText: 'Bs. ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Agregar al Carrito'),
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 1;
              final unitPrice = double.tryParse(priceController.text) ?? product.standardSellingPrice;
              
              vm.addItem(
                SaleItem(
                  productId: product.id,
                  productName: product.name,
                  quantity: qty,
                  unitPrice: unitPrice,
                  unitCost: product.latestCost ?? 0.0,
                ),
                product,
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: Column(
            children: [
              // Buscador Rápido por Nombre, SKU o Marca con botón de Deliveries
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Nombre, SKU o Marca...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              viewModel.searchProducts('');
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        onChanged: viewModel.searchProducts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delivery_dining),
                      tooltip: 'Gestionar Repartidores',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const DeliveryManagementDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Banner de Error
              if (viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(viewModel.error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ],
                    ),
                  ),
                ),

              // Lista de Productos
              Expanded(
                child: viewModel.isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No se encontraron productos coincidentes',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: viewModel.filteredProducts.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = viewModel.filteredProducts[index];
                              final availableStock = viewModel.getAvailableStock(product);
                              final bool isOutOfStock = availableStock <= 0;
                              
                              final cartItemIdx = viewModel.cart.indexWhere((i) => i.productId == product.id);
                              final cartQty = cartItemIdx >= 0 ? viewModel.cart[cartItemIdx].quantity : 0;
                              final cartPrice = cartItemIdx >= 0 ? viewModel.cart[cartItemIdx].unitPrice : product.standardSellingPrice;

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Status Indicator
                                      Container(
                                        width: 8,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isOutOfStock ? Colors.red : Colors.green,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Product Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${product.sku} | Marca: ${product.brand.isNotEmpty ? product.brand : "N/A"}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Stock (${viewModel.stockLocation}): $availableStock',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isOutOfStock ? Colors.red.shade700 : Colors.green.shade800,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Estándar: Bs. ${product.standardSellingPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                                if (product.promoterBasePrice != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Mayorista: Bs. ${product.promoterBasePrice!.toStringAsFixed(2)}',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Action / Cart controls
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (cartQty > 0) ...[
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () {
                                                if (cartQty > 1) {
                                                  viewModel.addItem(
                                                    SaleItem(
                                                      productId: product.id,
                                                      productName: product.name,
                                                      quantity: -1,
                                                      unitPrice: cartPrice,
                                                    ),
                                                    product,
                                                  );
                                                } else {
                                                  viewModel.removeItem(product.id);
                                                }
                                              },
                                            ),
                                            Text(
                                              '$cartQty',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: isOutOfStock
                                                ? null
                                                : () {
                                                    viewModel.addItem(
                                                      SaleItem(
                                                        productId: product.id,
                                                        productName: product.name,
                                                        quantity: 1,
                                                        unitPrice: product.standardSellingPrice,
                                                      ),
                                                      product,
                                                    );
                                                  },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.tune, size: 20, color: Colors.deepPurple),
                                            tooltip: 'Personalizar cantidad / precio',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: isOutOfStock ? null : () => _showAddCustomPriceDialog(context, product, viewModel),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          bottomNavigationBar: viewModel.cart.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${viewModel.cart.length} productos | Cliente: ${viewModel.selectedClient?.nombreAlias ?? "Mostrador"}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Total: Bs. ${viewModel.cartTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: viewModel.violatesAntiLoss ? Colors.red : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('Cobrar'),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const CheckoutBottomSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}
