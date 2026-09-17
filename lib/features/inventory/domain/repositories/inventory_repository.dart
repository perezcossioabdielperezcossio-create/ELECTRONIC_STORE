import '../entities/lot.dart';
import '../entities/product.dart';

/// Abstract repository defining domain operations for inventory.
abstract class InventoryRepository {
  /// Saves a new product along with its initial inventory lot.
  Future<void> saveProductWithInitialLot({
    required Product product,
    required Lot initialLot,
  });

  /// Adds a new lot of inventory to an existing product.
  Future<void> addLotToProduct({
    required String productId,
    required Lot lot,
  });

  /// Retrieves a product by its unique SKU.
  Future<Product?> getProductBySku(String sku);

  /// Retrieves all products that are considered part of the active inventory.
  Future<List<Product>> getActiveInventory();
}
