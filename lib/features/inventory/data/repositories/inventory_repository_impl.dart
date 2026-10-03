import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_local_data_source.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryLocalDataSource localDataSource;

  InventoryRepositoryImpl(this.localDataSource);

  @override
  Future<void> saveProductWithInitialLot({
    required Product product,
    required Lot initialLot,
  }) async {
    try {
      final productModel = ProductModel.fromEntity(product);
      final lotModel = LotModel.fromEntity(initialLot);
      await localDataSource.saveProductWithInitialLot(productModel, lotModel);
    } catch (e) {
      // Typically we would map this to a Failure if the signature used Either,
      // but since the abstract interface uses Future<void>, we just rethrow or wrap in a custom exception.
      rethrow;
    }
  }

  @override
  Future<void> addLotToProduct({
    required String productId,
    required Lot lot,
  }) async {
    final lotModel = LotModel.fromEntity(lot);
    await localDataSource.addLotToProduct(productId, lotModel);
  }

  @override
  Future<Product?> getProductBySku(String sku) async {
    return await localDataSource.getProductBySku(sku);
  }

  @override
  Future<List<Product>> getActiveInventory() async {
    return await localDataSource.getActiveInventory();
  }

  @override
  Future<Either<Failure, List<Lot>>> consumeStock(String productId, int quantity) async {
    try {
      final models = await localDataSource.consumeStock(productId, quantity);
      final entities = models.map((m) => Lot(
        id: m.id,
        productId: m.productId,
        purchaseDate: m.purchaseDate,
        initialQuantity: m.initialQuantity,
        currentQuantity: m.currentQuantity,
        realUnitCost: m.realUnitCost,
      )).toList();
      return Right(entities);
    } catch (e) {
      return Left(DatabaseFailure('Error consuming stock: \$e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      final models = await localDataSource.getAllProducts();
      final products = models.map<Product>((m) => m).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure('Error getting products: \$e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateProduct(Product product) async {
    try {
      final productModel = ProductModel.fromEntity(product);
      await localDataSource.updateProduct(productModel);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure('Error updating product: \$e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteProduct(String productId) async {
    try {
      await localDataSource.deleteProduct(productId);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure('Error deleting product: \$e'));
    }
  }
}
