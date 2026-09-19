import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/commission.dart';
import '../../domain/entities/promoter.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/promoter_repository.dart';
import '../datasources/promoter_local_datasource.dart';
import '../models/promoter_model.dart';
import '../models/reservation_model.dart';

class PromoterRepositoryImpl implements PromoterRepository {
  final PromoterLocalDatasource localDatasource;
  const PromoterRepositoryImpl(this.localDatasource);

  @override
  Future<Either<Failure, List<Promoter>>> getAllPromoters() async {
    try {
      return Right(await localDatasource.getAllPromoters());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Promoter>> getPromoterById(String id) async {
    try {
      return Right(await localDatasource.getPromoterById(id));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> savePromoter(Promoter promoter) async {
    try {
      await localDatasource.savePromoter(PromoterModel(
        id:             promoter.id,
        name:           promoter.name,
        phone:          promoter.phone,
        email:          promoter.email,
        commissionRate: promoter.commissionRate,
        isActive:       promoter.isActive,
      ));
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Commission>>> getCommissions(String promoterId) async {
    // TODO: implementar datasource de comisiones
    return const Right([]);
  }

  @override
  Future<Either<Failure, Unit>> recordCommission(Commission commission) async {
    // TODO: implementar datasource de comisiones
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> markCommissionPaid(String commissionId) async {
    // TODO: implementar datasource de comisiones
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> createReservation(Reservation reservation) async {
    try {
      await localDatasource.createReservation(ReservationModel(
        id: reservation.id,
        promoterId: reservation.promoterId,
        productId: reservation.productId,
        quantity: reservation.quantity,
        createdAt: reservation.createdAt,
        expiresAt: reservation.expiresAt,
        status: reservation.status,
      ));
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Reservation>>> getReservationsByPromoter(String promoterId) async {
    try {
      return Right(await localDatasource.getReservationsByPromoter(promoterId));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> checkAndExpireReservations() async {
    try {
      await localDatasource.checkAndExpireReservations();
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }
}
