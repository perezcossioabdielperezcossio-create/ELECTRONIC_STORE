import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/inventory_repository.dart';

class RevertOrAdjustStoreStockParams extends Equatable {
  final String? lotId;
  final String? productId;
  final int? newQuantity;

  const RevertOrAdjustStoreStockParams({
    this.lotId,
    this.productId,
    this.newQuantity,
  });

  @override
  List<Object?> get props => [lotId, productId, newQuantity];
}

class RevertOrAdjustStoreStockUseCase implements UseCase<Unit, RevertOrAdjustStoreStockParams> {
  final InventoryRepository repository;

  const RevertOrAdjustStoreStockUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RevertOrAdjustStoreStockParams params) {
    if (params.lotId == null && params.productId == null) {
      return Future.value(const Left(ValidationFailure('Debe especificarse al menos un lotId o productId')));
    }
    return repository.revertOrAdjustStoreStock(
      lotId: params.lotId,
      productId: params.productId,
      newQuantity: params.newQuantity,
    );
  }
}
