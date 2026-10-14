import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/inventory_repository.dart';

class TransferStockToStoreParams extends Equatable {
  final String productId;
  final int quantity;
  final String? sellerId;
  final String? storeLocation;

  const TransferStockToStoreParams({
    required this.productId,
    required this.quantity,
    this.sellerId,
    this.storeLocation = 'TIENDA',
  });

  @override
  List<Object?> get props => [productId, quantity, sellerId, storeLocation];
}

class TransferStockToStoreUseCase implements UseCase<Unit, TransferStockToStoreParams> {
  final InventoryRepository repository;

  const TransferStockToStoreUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(TransferStockToStoreParams params) {
    if (params.quantity <= 0) {
      return Future.value(const Left(ValidationFailure('La cantidad a transferir debe ser mayor a 0')));
    }
    return repository.transferStockToStore(
      productId: params.productId,
      quantity: params.quantity,
      sellerId: params.sellerId,
      storeLocation: params.storeLocation,
    );
  }
}
