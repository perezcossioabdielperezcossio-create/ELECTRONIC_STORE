import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/lot.dart';
import '../repositories/inventory_repository.dart';

class AddLotUseCase implements UseCase<Unit, AddLotParams> {
  final InventoryRepository repository;
  const AddLotUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AddLotParams params) =>
      repository.addLotToProduct(productId: params.productId, lot: params.lot).then((_) => const Right(unit));
}

class AddLotParams extends Equatable {
  final String productId;
  final Lot lot;
  const AddLotParams({required this.productId, required this.lot});

  @override
  List<Object> get props => [productId, lot];
}
