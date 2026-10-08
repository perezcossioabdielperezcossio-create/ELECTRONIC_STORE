import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/delivery_repository.dart';

class DeleteDeliveryUseCase implements UseCase<Unit, String> {
  final DeliveryRepository repository;

  DeleteDeliveryUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String id) {
    return repository.deleteDelivery(id);
  }
}
