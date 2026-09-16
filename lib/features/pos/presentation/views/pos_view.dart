import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pos_viewmodel.dart';
import '../widgets/cart_item_tile.dart';

class PosView extends StatelessWidget {
  const PosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punto de Venta')),
      body: Consumer<PosViewModel>(
        builder: (context, vm, _) {
          if (vm.cart.isEmpty) {
            return const Center(child: Text('Carrito vacío'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: vm.cart.length,
                  itemBuilder: (_, i) => CartItemTile(item: vm.cart[i]),
                ),
              ),
              _OrderSummary(vm: vm),
            ],
          );
        },
      ),
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
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total: RD\$ \',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: vm.isLoading ? null : () => vm.checkout(),
            child: vm.isLoading
                ? const CircularProgressIndicator()
                : const Text('Cobrar'),
          ),
        ],
      ),
    );
  }
}
