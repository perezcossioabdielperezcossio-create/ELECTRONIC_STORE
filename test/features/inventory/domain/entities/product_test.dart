import 'package:flutter_test/flutter_test.dart';
import 'package:electronic_store/features/inventory/domain/entities/lot.dart';
import 'package:electronic_store/features/inventory/domain/entities/product.dart';

void main() {
  group('Product Entity', () {
    final lot1 = Lot(
      id: 'l1',
      productId: 'p1',
      purchaseDate: DateTime(2023, 1, 1),
      initialQuantity: 10,
      currentQuantity: 10,
      realUnitCost: 100.0,
    );

    final lot2Inactive = Lot(
      id: 'l2',
      productId: 'p1',
      purchaseDate: DateTime(2023, 2, 1),
      initialQuantity: 10,
      currentQuantity: 0, // Inactive lot
      realUnitCost: 150.0,
    );

    final lot3 = Lot(
      id: 'l3',
      productId: 'p1',
      purchaseDate: DateTime(2023, 3, 1),
      initialQuantity: 5,
      currentQuantity: 5,
      realUnitCost: 120.0,
    );

    test('should calculate availableStock summing only active lots', () {
      final product = Product(
        id: 'p1',
        sku: 'SKU1',
        name: 'Product 1',
        category: 'Category',
        sellingPrice: 200.0,
        minStockThreshold: 5,
        lots: [lot1, lot2Inactive, lot3],
      );

      // Active lots sum: lot1 (10) + lot3 (5) = 15. lot2Inactive (0) should be ignored.
      expect(product.availableStock, 15);
    });

    test('should return correct StockStatus based on availableStock and minStockThreshold', () {
      // 1. outOfStock (availableStock == 0)
      final outOfStockProduct = Product(
        id: 'p1',
        sku: 'SKU1',
        name: 'Product 1',
        category: 'Category',
        sellingPrice: 200.0,
        minStockThreshold: 5,
        lots: [lot2Inactive], // 0 active stock
      );
      expect(outOfStockProduct.status, StockStatus.outOfStock);

      // 2. lowStock (availableStock <= minStockThreshold)
      final lowStockProduct = Product(
        id: 'p1',
        sku: 'SKU1',
        name: 'Product 1',
        category: 'Category',
        sellingPrice: 200.0,
        minStockThreshold: 10,
        lots: [lot1], // 10 active stock, threshold is 10
      );
      expect(lowStockProduct.status, StockStatus.lowStock);

      // 3. available (availableStock > minStockThreshold)
      final availableProduct = Product(
        id: 'p1',
        sku: 'SKU1',
        name: 'Product 1',
        category: 'Category',
        sellingPrice: 200.0,
        minStockThreshold: 5,
        lots: [lot1], // 10 active stock, threshold is 5
      );
      expect(availableProduct.status, StockStatus.available);
    });

    test('should accurately calculate totalInvestedCapital without averaging costs', () {
      final product = Product(
        id: 'p1',
        sku: 'SKU1',
        name: 'Product 1',
        category: 'Category',
        sellingPrice: 200.0,
        minStockThreshold: 5,
        lots: [lot1, lot2Inactive, lot3],
      );

      // lot1: 10 * 100.0 = 1000.0
      // lot2Inactive: 0 * 150.0 = 0.0 (inactive, shouldn't add to capital)
      // lot3: 5 * 120.0 = 600.0
      // Total invested capital expected: 1600.0
      expect(product.totalInvestedCapital, 1600.0);
    });
  });
}
