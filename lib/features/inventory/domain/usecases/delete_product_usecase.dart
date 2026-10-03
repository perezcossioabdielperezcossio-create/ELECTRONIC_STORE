import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/inventory_repository.dart';

class DeleteProductUseCase implements UseCase<Unit, DeleteProductParams> {
  final InventoryRepository repository;

  DeleteProductUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteProductParams params) async {
    return await repository.deleteProduct(params.productId);
  }
}

class DeleteProductParams extends Equatable {
  final String productId;

  const DeleteProductParams({required this.productId});

  @override
  List<Object> get props => [productId];
}
