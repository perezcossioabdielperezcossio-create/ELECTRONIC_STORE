import '../../domain/entities/inventory_batch.dart';

class InventoryBatchModel extends InventoryBatch {
  const InventoryBatchModel({
    required super.id,
    required super.productId,
    required super.quantity,
    required super.costPrice,
    required super.receivedAt,
    super.supplierName,
  });

  factory InventoryBatchModel.fromMap(Map<String, dynamic> map) =>
      InventoryBatchModel(
        id:           map['id'] as String,
        productId:    map['product_id'] as String,
        quantity:     map['quantity'] as int,
        costPrice:    (map['cost_price'] as num).toDouble(),
        receivedAt:   DateTime.parse(map['received_at'] as String),
        supplierName: map['supplier_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':            id,
        'product_id':    productId,
        'quantity':      quantity,
        'cost_price':    costPrice,
        'received_at':   receivedAt.toIso8601String(),
        'supplier_name': supplierName,
      };
}
