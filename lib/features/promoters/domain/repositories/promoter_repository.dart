import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/commission.dart';
import '../entities/promoter.dart';
import '../entities/reservation.dart';

abstract class PromoterRepository {
  Future<Either<Failure, List<Promoter>>>   getAllPromoters();
  Future<Either<Failure, Promoter>>         getPromoterById(String id);
  Future<Either<Failure, Unit>>             savePromoter(Promoter promoter);
  
  // Commissions
  Future<Either<Failure, List<Commission>>> getCommissions(String promoterId);
  Future<Either<Failure, Unit>>             recordCommission(Commission commission);
  Future<Either<Failure, Unit>>             markCommissionPaid(String commissionId);

  // Reservations
  Future<Either<Failure, Unit>>             createReservation(Reservation reservation);
  Future<Either<Failure, List<Reservation>>> getReservationsByPromoter(String promoterId);
  Future<Either<Failure, Unit>>             checkAndExpireReservations();
}
