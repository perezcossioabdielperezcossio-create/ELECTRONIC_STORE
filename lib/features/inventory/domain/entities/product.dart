import 'lot.dart';

/// Represents the availability status of a product's stock.
enum StockStatus {
  available,
  lowStock,
  outOfStock,
}

/// Represents a product in the inventory catalog.
class Product {
  final String id;
  final String sku;
  final String name;
  final String brand;
  final String category;
  final double standardSellingPrice;
  final int minStockThreshold;
  final int activeReservedUnits;
  final List<Lot> lots;

  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.brand,
    required this.category,
    required this.standardSellingPrice,
    required this.minStockThreshold,
    this.activeReservedUnits = 0,
    this.lots = const [],
  })  : assert(
          standardSellingPrice >= 0,
          'Standard selling price cannot be negative',
        ),
        assert(
          minStockThreshold >= 0,
          'Minimum stock threshold cannot be negative',
        );

  /// The total sum of remaining quantities from all active lots.
  int get availableStock {
    final totalActiveLotStock = lots
        .where((lot) => lot.isActive)
        .fold(0, (sum, lot) => sum + lot.currentQuantity);
    return totalActiveLotStock - activeReservedUnits;
  }

  /// The current status of the product based on available stock and threshold.
  StockStatus get status {
    final stock = availableStock;
    if (stock <= 0) {
      return StockStatus.outOfStock;
    } else if (stock <= minStockThreshold) {
      return StockStatus.lowStock;
    } else {
      return StockStatus.available;
    }
  }

  /// The real unit cost of the most recently purchased lot.
  /// Returns null if there are no lots.
  double? get latestCost {
    if (lots.isEmpty) return null;
    final sortedLots = List<Lot>.from(lots)
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return sortedLots.first.realUnitCost;
  }

  /// The total capital tied up in all active lots of this product.
  double get totalInvestedCapital {
    return lots
        .where((lot) => lot.isActive)
        .fold(0.0, (sum, lot) => sum + lot.totalHoldingCapital);
  }

  Product copyWith({
    String? id,
    String? sku,
    String? name,
    String? brand,
    String? category,
    double? standardSellingPrice,
    int? minStockThreshold,
    int? activeReservedUnits,
    List<Lot>? lots,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      standardSellingPrice: standardSellingPrice ?? this.standardSellingPrice,
      minStockThreshold: minStockThreshold ?? this.minStockThreshold,
      activeReservedUnits: activeReservedUnits ?? this.activeReservedUnits,
      lots: lots ?? this.lots,
    );
  }
}
