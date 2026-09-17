import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_local_data_source.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/inventory_batch.dart';
import '../models/inventory_batch_model.dart';

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
  Future<Either<Failure, Unit>> addBatch(InventoryBatch batch) async {
    try {
      final model = InventoryBatchModel(
        id: batch.id,
        productId: batch.productId,
        quantity: batch.quantity,
        costPrice: batch.costPrice,
        receivedAt: batch.receivedAt,
      );
      await localDataSource.addBatch(model);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure('Error adding batch: \$e'));
    }
  }

  @override
  Future<Either<Failure, List<InventoryBatch>>> consumeStock(String productId, int quantity) async {
    try {
      final models = await localDataSource.consumeStock(productId, quantity);
      final entities = models.map((m) => InventoryBatch(
        id: m.id,
        productId: m.productId,
        quantity: m.quantity,
        costPrice: m.costPrice,
        receivedAt: m.receivedAt,
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
}
