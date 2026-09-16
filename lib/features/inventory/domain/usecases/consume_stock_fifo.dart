import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inventory_batch.dart';
import '../repositories/inventory_repository.dart';

class ConsumeStockFifo implements UseCase<List<InventoryBatch>, ConsumeStockParams> {
  final InventoryRepository repository;
  const ConsumeStockFifo(this.repository);

  @override
  Future<Either<Failure, List<InventoryBatch>>> call(ConsumeStockParams params) =>
      repository.consumeStock(params.productId, params.quantity);
}

class ConsumeStockParams extends Equatable {
  final String productId;
  final int quantity;
  const ConsumeStockParams({required this.productId, required this.quantity});

  @override
  List<Object> get props => [productId, quantity];
}
