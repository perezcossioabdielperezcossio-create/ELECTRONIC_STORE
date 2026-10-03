/// Represents a specific batch or lot of a product in inventory.
class Lot {
  final String id;
  final String productId;
  final DateTime purchaseDate;
  final int initialQuantity;
  final int currentQuantity;
  final double realUnitCost;
  final double? promoterBasePrice;

  const Lot({
    required this.id,
    required this.productId,
    required this.purchaseDate,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.realUnitCost,
    this.promoterBasePrice,
  })  : assert(initialQuantity >= 0, 'Initial quantity cannot be negative'),
        assert(currentQuantity >= 0, 'Current quantity cannot be negative'),
        assert(
          currentQuantity <= initialQuantity,
          'Current quantity cannot exceed initial quantity',
        ),
        assert(realUnitCost >= 0, 'Real unit cost cannot be negative'),
        assert(
          promoterBasePrice == null || promoterBasePrice >= 0,
          'Promoter base price cannot be negative',
        );

  /// Indicates if this lot still has available stock.
  bool get isActive => currentQuantity > 0;

  /// The total capital tied up in this specific lot.
  double get totalHoldingCapital => currentQuantity * realUnitCost;

  Lot copyWith({
    String? id,
    String? productId,
    DateTime? purchaseDate,
    int? initialQuantity,
    int? currentQuantity,
    double? realUnitCost,
    double? promoterBasePrice,
  }) {
    return Lot(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      realUnitCost: realUnitCost ?? this.realUnitCost,
      promoterBasePrice: promoterBasePrice ?? this.promoterBasePrice,
    );
  }
}
