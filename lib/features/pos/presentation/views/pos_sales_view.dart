import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pos_viewmodel.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../../domain/entities/sale_item.dart';

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
      context.read<PosViewModel>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: Column(
            children: [
              // Buscador
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto por SKU o nombre...',
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
                  ),
                  onChanged: viewModel.searchProducts,
                ),
              ),
              
              // Errores
              if (viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.shade100,
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(viewModel.error!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),

              // Lista de productos
              Expanded(
                child: viewModel.isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: viewModel.filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = viewModel.filteredProducts[index];
                          final bool isOutOfStock = product.availableStock <= 0;
                          
                          final cartItemIdx = viewModel.cart.indexWhere((i) => i.productId == product.id);
                          final cartQty = cartItemIdx >= 0 ? viewModel.cart[cartItemIdx].quantity : 0;

                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text('SKU: ${product.sku} | Stock: ${product.availableStock}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Bs. ${product.standardSellingPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                if (cartQty > 0)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () {
                                      if (cartQty > 1) {
                                        viewModel.addItem(
                                          SaleItem(
                                            productId: product.id,
                                            productName: product.name,
                                            quantity: -1, // Reduce quantity
                                            unitPrice: product.standardSellingPrice,
                                          ),
                                          product,
                                        );
                                      } else {
                                        viewModel.removeItem(product.id);
                                      }
                                    },
                                  ),
                                if (cartQty > 0)
                                  Text(
                                    '$cartQty',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: isOutOfStock
                                      ? null
                                      : () {
                                          viewModel.addItem(
                                            SaleItem(
                                              productId: product.id,
                                              productName: product.name,
                                              quantity: 1, // Increase quantity
                                              unitPrice: product.standardSellingPrice,
                                            ),
                                            product,
                                          );
                                        },
                                ),
                              ],
                            ),
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOutOfStock ? Colors.red : Colors.green,
                              ),
                            ),
                            onTap: isOutOfStock
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
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: viewModel.cart.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CheckoutBottomSheet(),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('Pagar Bs. ${viewModel.cartTotal.toStringAsFixed(2)}'),
                  backgroundColor: Theme.of(context).primaryColor,
                )
              : null,
        );
      },
    );
  }
}
