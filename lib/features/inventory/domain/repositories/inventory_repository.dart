import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/product.dart';
import '../entities/inventory_batch.dart';

abstract class InventoryRepository {
  Future<Either<Failure, List<Product>>>        getAllProducts();
  Future<Either<Failure, Product>>              getProductById(String id);
  Future<Either<Failure, Unit>>                 saveProduct(Product product);
  Future<Either<Failure, Unit>>                 deleteProduct(String id);

  // FIFO batches
  Future<Either<Failure, List<InventoryBatch>>> getBatchesForProduct(String productId);
  Future<Either<Failure, Unit>>                 addBatch(InventoryBatch batch);
  Future<Either<Failure, int>>                  getStockTotal(String productId);

  /// Reduce stock usando FIFO. Retorna los lotes consumidos.
  Future<Either<Failure, List<InventoryBatch>>> consumeStock(String productId, int quantity);
}
