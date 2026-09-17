import '../entities/lot.dart';
import '../entities/product.dart';
import '../repositories/inventory_repository.dart';

/// Exception thrown when attempting to create a product with a SKU that already exists in the inventory.
class DuplicateSkuException implements Exception {
  final String message;

  const DuplicateSkuException(this.message);

  @override
  String toString() => 'DuplicateSkuException: $message';
}

/// Use case for creating a new product alongside its initial lot.
class CreateProductWithLotUseCase {
  final InventoryRepository repository;

  CreateProductWithLotUseCase(this.repository);

  Future<void> call({
    required Product product,
    required Lot initialLot,
  }) async {
    // Validate RF-01: Check if a product with the same SKU already exists
    final existingProduct = await repository.getProductBySku(product.sku);
    if (existingProduct != null) {
      throw DuplicateSkuException(
        'A product with SKU "${product.sku}" already exists in the inventory.',
      );
    }

    // Validate RF-02: Initial quantity must be > 0 and real unit cost >= 0
    if (initialLot.initialQuantity <= 0) {
      throw ArgumentError('The initial lot must have a quantity greater than zero.');
    }
    if (initialLot.realUnitCost < 0) {
      throw ArgumentError('The real unit cost of the initial lot cannot be negative.');
    }

    // Save if all validations pass
    await repository.saveProductWithInitialLot(
      product: product,
      initialLot: initialLot,
    );
  }
}
