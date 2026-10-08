import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_local_datasource.dart';
import '../models/delivery_model.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  final DeliveryLocalDataSource localDataSource;

  DeliveryRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, List<Delivery>>> getDeliveries({bool onlyActive = false}) async {
    try {
      final list = await localDataSource.getDeliveries(onlyActive: onlyActive);
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener repartidores: $e'));
    }
  }

  @override
  Future<Either<Failure, Delivery?>> getDeliveryById(String id) async {
    try {
      final item = await localDataSource.getDeliveryById(id);
      return Right(item);
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener repartidor: $e'));
    }
  }

  @override
  Future<Either<Failure, Delivery>> saveDelivery(Delivery delivery) async {
    try {
      final model = DeliveryModel.fromEntity(delivery);
      await localDataSource.saveDelivery(model);
      return Right(model);
    } catch (e) {
      return Left(DatabaseFailure('Error al guardar repartidor: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteDelivery(String id) async {
    try {
      await localDataSource.deleteDelivery(id);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure('Error al eliminar repartidor: $e'));
    }
  }
}
