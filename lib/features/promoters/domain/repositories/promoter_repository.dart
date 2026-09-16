import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/commission.dart';
import '../entities/promoter.dart';

abstract class PromoterRepository {
  Future<Either<Failure, List<Promoter>>>   getAllPromoters();
  Future<Either<Failure, Promoter>>         getPromoterById(String id);
  Future<Either<Failure, Unit>>             savePromoter(Promoter promoter);
  Future<Either<Failure, List<Commission>>> getCommissions(String promoterId);
  Future<Either<Failure, Unit>>             recordCommission(Commission commission);
  Future<Either<Failure, Unit>>             markCommissionPaid(String commissionId);
}
