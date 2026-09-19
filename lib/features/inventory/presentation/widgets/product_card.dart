import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

import 'stock_status_badge.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(product.name[0])),
        title:   Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${product.sku} · ${product.category}'),
            const SizedBox(height: 4),
            StockStatusBadge(status: product.status),
          ],
        ),
        trailing: Text(
          'Bs ${product.standardSellingPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
