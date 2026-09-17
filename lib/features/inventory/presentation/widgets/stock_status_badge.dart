import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

class StockStatusBadge extends StatelessWidget {
  final StockStatus status;

  const StockStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case StockStatus.available:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Disponible';
        icon = Icons.check_circle_outline;
        break;
      case StockStatus.lowStock:
        backgroundColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        label = 'Stock Bajo';
        icon = Icons.warning_amber_rounded;
        break;
      case StockStatus.outOfStock:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        label = 'Agotado';
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16.0,
            color: textColor,
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
