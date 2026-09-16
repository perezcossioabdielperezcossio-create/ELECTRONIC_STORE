import 'package:equatable/equatable.dart';

/// Representa un lote FIFO de un producto.
class InventoryBatch extends Equatable {
  final String id;
  final String productId;
  final int quantity;
  final double costPrice;
  final DateTime receivedAt;
  final String? supplierName;

  const InventoryBatch({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.costPrice,
    required this.receivedAt,
    this.supplierName,
  });

  bool get isEmpty => quantity <= 0;

  @override
  List<Object?> get props =>
      [id, productId, quantity, costPrice, receivedAt, supplierName];
}
