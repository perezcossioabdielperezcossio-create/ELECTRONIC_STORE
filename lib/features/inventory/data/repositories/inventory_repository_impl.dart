import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_local_data_source.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart'; // Assuming a standard core/error structure

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
}
