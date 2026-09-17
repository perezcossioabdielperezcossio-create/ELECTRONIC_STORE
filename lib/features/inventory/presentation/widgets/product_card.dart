import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text(product.name[0])),
        title:   Text(product.name),
        subtitle: Text('SKU: ${product.sku} · Stock: ${product.availableStock}'),
        trailing: Text(
          'RD\$ ${product.latestCost?.toStringAsFixed(2) ?? '0.00'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
