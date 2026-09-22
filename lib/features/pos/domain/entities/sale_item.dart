import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double lineDiscount;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0.0,
    this.lineDiscount = 0,
  });

  double get lineTotal => (unitPrice * quantity) - lineDiscount;

  @override
  List<Object> get props =>
      [productId, productName, quantity, unitPrice, unitCost, lineDiscount];
}
