import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/delivery.dart';

abstract class DeliveryRepository {
  Future<Either<Failure, List<Delivery>>> getDeliveries({bool onlyActive = false});
  Future<Either<Failure, Delivery?>> getDeliveryById(String id);
  Future<Either<Failure, Delivery>> saveDelivery(Delivery delivery);
  Future<Either<Failure, Unit>> deleteDelivery(String id);
}
