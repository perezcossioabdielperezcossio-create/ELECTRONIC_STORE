import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/sale_item.dart';
import '../../../inventory/domain/entities/product.dart';
import '../viewmodels/pos_viewmodel.dart';
import '../widgets/cart_item_tile.dart';

import '../widgets/recent_sales_bottom_sheet.dart';

class PosView extends StatefulWidget {
  const PosView({super.key});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosViewModel>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRecentSales(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const RecentSalesBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Historial de Hoy',
            onPressed: () => _showRecentSales(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por SKU o Nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    // Mock QR Scanner
                  },
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) =>
                  context.read<PosViewModel>().searchProducts(val),
            ),
          ),
        ),
      ),
      body: Consumer<PosViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoadingProducts) {
            return const Center(child: CircularProgressIndicator());
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (vm.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(vm.error!),
                  backgroundColor: Colors.red,
                ),
              );
              // Clear error after showing so it doesn't loop
              // We'll rely on the ViewModel clearing it on next success or manually
            }
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: vm.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = vm.filteredProducts[index];
                    final hasStock = product.availableStock > 0;
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('SKU: ${product.sku} | Sugerido: RD\$${product.standardSellingPrice}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasStock ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Stock: ${product.availableStock}',
                          style: TextStyle(
                            color: hasStock ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: hasStock ? () => _showAddToCartDialog(context, product, vm) : null,
                    );
                  },
                ),
              ),
              if (vm.cart.isNotEmpty) _OrderSummary(vm: vm),
            ],
          );
        },
      ),
    );
  }

  void _showAddToCartDialog(BuildContext context, Product product, PosViewModel vm) {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: product.standardSellingPrice.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio Venta'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text) ?? 1;
                final price = double.tryParse(priceCtrl.text) ?? product.standardSellingPrice;
                
                final item = SaleItem(
                  productId: product.id,
                  productName: product.name,
                  quantity: qty,
                  unitPrice: price,
                );
                
                vm.addItem(item, product);
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final PosViewModel vm;
  const _OrderSummary({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${vm.cart.length} ítems en carrito', style: Theme.of(context).textTheme.titleMedium),
              Text('Total: RD\$ ${vm.cartTotal}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => _showCartDetails(context, vm),
                  label: const Text('Ver Carrito'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: vm.isLoading ? null : () => _showCheckoutSheet(context, vm),
                  child: vm.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cobrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCartDetails(BuildContext context, PosViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Carrito de Compras', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: vm.cart.length,
                    itemBuilder: (context, i) => CartItemTile(item: vm.cart[i]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCheckoutSheet(BuildContext context, PosViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Finalizar Venta', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  
                  // RF-10: Payment Method
                  const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'EFECTIVO', label: Text('Efectivo')),
                      ButtonSegment(value: 'TRANSFERENCIA', label: Text('Transferencia')),
                    ],
                    selected: {vm.paymentMethod},
                    onSelectionChanged: (val) {
                      vm.setPaymentMethod(val.first);
                      setState((){});
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // RF-10: Delivery Method
                  const Text('Modalidad de Entrega', style: TextStyle(fontWeight: FontWeight.bold)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'TIENDA', label: Text('Retiro en Tienda')),
                      ButtonSegment(value: 'DELIVERY', label: Text('Delivery')),
                    ],
                    selected: {vm.deliveryMethod},
                    onSelectionChanged: (val) {
                      vm.setDeliveryMethod(val.first);
                      if (val.first == 'TIENDA') {
                        vm.setDeliveryFee(0);
                      }
                      setState((){});
                    },
                  ),
                  
                  if (vm.deliveryMethod == 'DELIVERY') ...[
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo de Flete (RD\$)'),
                      onChanged: (val) => vm.setDeliveryFee(double.tryParse(val) ?? 0),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // RF-12: Customer Data (Optional)
                  const Text('Datos del Cliente (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    onChanged: vm.setCustomerName,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp'),
                    onChanged: vm.setCustomerPhone,
                  ),
                  const SizedBox(height: 24),
                  
                  FilledButton(
                    onPressed: () async {
                      final success = await vm.checkout();
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Venta completada exitosamente')),
                        );
                      }
                    },
                    child: Text('Confirmar Cobro (RD\$ ${vm.cartTotal + vm.deliveryFee})'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
