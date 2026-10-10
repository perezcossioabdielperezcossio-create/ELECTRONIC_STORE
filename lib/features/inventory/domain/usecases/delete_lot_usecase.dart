import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/inventory_repository.dart';

class DeleteLotUseCase implements UseCase<Unit, DeleteLotParams> {
  final InventoryRepository repository;
  const DeleteLotUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteLotParams params) =>
      repository.deleteLot(params.lotId);
}

class DeleteLotParams extends Equatable {
  final String lotId;
  const DeleteLotParams({required this.lotId});

  @override
  List<Object> get props => [lotId];
}
