import 'lot.dart';

enum StockStatus {
  available,
  lowStock,
  outOfStock,
}

class Product {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double sellingPrice;
  final String? imageUrl;
  final bool isActive;
  final int minStockThreshold;
  final List<Lot> lots;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.sellingPrice,
    this.imageUrl,
    this.isActive = true,
    this.minStockThreshold = 0,
    this.lots = const [],
  });

  int get availableStock {
    return lots
        .where((lot) => lot.isActive)
        .fold(0, (sum, lot) => sum + lot.currentQuantity);
  }

  StockStatus get status {
    final stock = availableStock;
    if (stock == 0) {
      return StockStatus.outOfStock;
    } else if (stock <= minStockThreshold) {
      return StockStatus.lowStock;
    } else {
      return StockStatus.available;
    }
  }

  double? get latestCost {
    if (lots.isEmpty) return null;
    final sortedLots = List<Lot>.from(lots)
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return sortedLots.first.realUnitCost;
  }

  double get totalInvestedCapital {
    return lots
        .where((lot) => lot.isActive)
        .fold(0.0, (sum, lot) => sum + lot.totalHoldingCapital);
  }

}
