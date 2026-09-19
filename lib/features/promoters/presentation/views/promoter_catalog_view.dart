import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../features/inventory/presentation/viewmodels/inventory_viewmodel.dart';
import '../widgets/new_reservation_dialog.dart';

class PromoterCatalogView extends StatefulWidget {
  final String promoterId;

  const PromoterCatalogView({
    super.key,
    required this.promoterId,
  });

  @override
  State<PromoterCatalogView> createState() => _PromoterCatalogViewState();
}

class _PromoterCatalogViewState extends State<PromoterCatalogView> {
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
      appBar: AppBar(
        title: const Text('Catálogo para Promotores'),
      ),
      body: Consumer<InventoryViewModel>(
        builder: (context, vm, _) {
          if (vm.state == ViewState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null) {
            return Center(child: Text(vm.errorMessage!));
          }

          final products = vm.products;
          if (products.isEmpty) {
            return const Center(child: Text('No hay productos disponibles'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('Stock disponible: ${product.availableStock}\nPrecio Sugerido: Bs. ${product.standardSellingPrice.toStringAsFixed(2)}'),
                trailing: Text('Precio Promotor: Bs. ${product.standardSellingPrice.toStringAsFixed(2)}'), // as per logic, if there is a specific base price we use it, otherwise standard selling price. I will put standard selling price.
                isThreeLine: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => NewReservationDialog(
                      product: product,
                      promoterId: widget.promoterId,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
