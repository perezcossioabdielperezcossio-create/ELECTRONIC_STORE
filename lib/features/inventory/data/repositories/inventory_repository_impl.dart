import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_local_datasource.dart';
import '../models/inventory_batch_model.dart';
import '../models/product_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryLocalDatasource localDatasource;
  const InventoryRepositoryImpl(this.localDatasource);

  @override
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      return Right(await localDatasource.getAllProducts());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductById(String id) async {
    try {
      return Right(await localDatasource.getProductById(id));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveProduct(Product product) async {
    try {
      await localDatasource.saveProduct(ProductModel.fromEntity(product));
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteProduct(String id) async {
    try {
      await localDatasource.deleteProduct(id);
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<InventoryBatch>>> getBatchesForProduct(
      String productId) async {
    try {
      return Right(await localDatasource.getBatchesForProduct(productId));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> addBatch(InventoryBatch batch) async {
    try {
      await localDatasource.addBatch(InventoryBatchModel(
        id:           batch.id,
        productId:    batch.productId,
        quantity:     batch.quantity,
        costPrice:    batch.costPrice,
        receivedAt:   batch.receivedAt,
        supplierName: batch.supplierName,
      ));
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getStockTotal(String productId) async {
    try {
      final batches = await localDatasource.getBatchesForProduct(productId);
      final total   = batches.fold<int>(0, (sum, b) => sum + b.quantity);
      return Right(total);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<InventoryBatch>>> consumeStock(
      String productId, int quantity) async {
    try {
      return Right(
          await localDatasource.consumeStock(productId, quantity));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }
}
