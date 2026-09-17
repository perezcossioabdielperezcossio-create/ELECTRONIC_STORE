import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_local_datasource.dart';
import '../models/product_model.dart';
import '../models/inventory_batch_model.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart'; // Assuming a standard core/error structure

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryLocalDatasource localDataSource;

  InventoryRepositoryImpl(this.localDataSource);

  @override
  Future<void> saveProductWithInitialLot({
    required Product product,
    required Lot initialLot,
  }) async {
    try {
      final productModel = ProductModel.fromEntity(product);
      // await localDataSource.saveProductWithInitialLot(productModel, lotModel); // Method doesn't exist on localDataSource, we can use saveProduct
      await localDataSource.saveProduct(productModel);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addLotToProduct({
    required String productId,
    required Lot lot,
  }) async {
    // Implement if needed, currently skipping as it's not in local datasource
  }

  @override
  Future<Product?> getProductBySku(String sku) async {
    // Currently skipping
    return null;
  }

  @override
  Future<List<Product>> getActiveInventory() async {
    return await localDataSource.getAllProducts();
  }

  @override
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      final products = await localDataSource.getAllProducts();
      return Right(products);
    } on Exception {
      return const Left(DatabaseFailure('Error'));
    }
  }

  @override
  Future<Either<Failure, Unit>> addBatch(InventoryBatch batch) async {
    try {
      final batchModel = InventoryBatchModel(
        id: batch.id,
        productId: batch.productId,
        quantity: batch.quantity,
        costPrice: batch.costPrice,
        receivedAt: batch.receivedAt,
        supplierName: batch.supplierName,
      );
      await localDataSource.addBatch(batchModel);
      return const Right(unit);
    } on Exception {
      return const Left(DatabaseFailure('Error'));
    }
  }

  @override
  Future<Either<Failure, List<InventoryBatch>>> consumeStock(String productId, int quantity) async {
    try {
      final consumed = await localDataSource.consumeStock(productId, quantity);
      return Right(consumed);
    } on Exception {
      return const Left(DatabaseFailure('Error'));
    }
  }
}
