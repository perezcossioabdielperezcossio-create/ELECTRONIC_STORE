import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product.dart';
import '../repositories/inventory_repository.dart';

class GetAllProducts implements UseCase<List<Product>, NoParams> {
  final InventoryRepository repository;
  const GetAllProducts(this.repository);

  @override
  Future<Either<Failure, List<Product>>> call(NoParams params) =>
      repository.getAllProducts();
}
