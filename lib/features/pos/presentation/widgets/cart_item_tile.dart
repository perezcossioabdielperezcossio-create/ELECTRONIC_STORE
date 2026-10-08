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
      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${item.quantity} × Bs. ${item.unitPrice.toStringAsFixed(2)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bs. ${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => context.read<PosViewModel>().removeItem(item.productId),
          ),
        ],
      ),
    );
  }
}
