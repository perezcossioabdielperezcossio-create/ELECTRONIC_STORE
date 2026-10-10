import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class SaveDeliveryUseCase implements UseCase<Delivery, Delivery> {
  final DeliveryRepository repository;

  SaveDeliveryUseCase(this.repository);

  @override
  Future<Either<Failure, Delivery>> call(Delivery delivery) {
    return repository.saveDelivery(delivery);
  }
}
