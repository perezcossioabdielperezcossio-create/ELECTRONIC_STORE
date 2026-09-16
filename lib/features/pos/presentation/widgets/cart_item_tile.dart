import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/sale_item.dart';
import '../viewmodels/pos_viewmodel.dart';

class CartItemTile extends StatelessWidget {
  final SaleItem item;
  const CartItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title:    Text(item.productName),
      subtitle: Text('\ × RD\$ \'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('RD\$ \',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                context.read<PosViewModel>().removeItem(item.productId),
          ),
        ],
      ),
    );
  }
}
