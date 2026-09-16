import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inventory_batch.dart';
import '../repositories/inventory_repository.dart';

class AddInventoryBatch implements UseCase<Unit, AddBatchParams> {
  final InventoryRepository repository;
  const AddInventoryBatch(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AddBatchParams params) =>
      repository.addBatch(params.batch);
}

class AddBatchParams extends Equatable {
  final InventoryBatch batch;
  const AddBatchParams(this.batch);

  @override
  List<Object> get props => [batch];
}
