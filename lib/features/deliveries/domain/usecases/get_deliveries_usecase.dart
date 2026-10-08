import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class GetDeliveriesParams {
  final bool onlyActive;
  const GetDeliveriesParams({this.onlyActive = false});
}

class GetDeliveriesUseCase implements UseCase<List<Delivery>, GetDeliveriesParams> {
  final DeliveryRepository repository;

  GetDeliveriesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Delivery>>> call(GetDeliveriesParams params) {
    return repository.getDeliveries(onlyActive: params.onlyActive);
  }
}
