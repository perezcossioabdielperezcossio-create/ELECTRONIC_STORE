import '../../domain/entities/lot.dart';

class LotModel extends Lot {
  const LotModel({
    required super.id,
    required super.productId,
    required super.purchaseDate,
    required super.initialQuantity,
    required super.currentQuantity,
    required super.realUnitCost,
  });

  factory LotModel.fromMap(Map<String, dynamic> map) {
    return LotModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      initialQuantity: map['initial_quantity'] as int,
      currentQuantity: map['current_quantity'] as int,
      realUnitCost: (map['real_unit_cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'purchase_date': purchaseDate.toIso8601String(),
      'initial_quantity': initialQuantity,
      'current_quantity': currentQuantity,
      'real_unit_cost': realUnitCost,
    };
  }

  factory LotModel.fromEntity(Lot lot) {
    return LotModel(
      id: lot.id,
      productId: lot.productId,
      purchaseDate: lot.purchaseDate,
      initialQuantity: lot.initialQuantity,
      currentQuantity: lot.currentQuantity,
      realUnitCost: lot.realUnitCost,
    );
  }
}
