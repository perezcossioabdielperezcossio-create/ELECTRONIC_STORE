import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/commission.dart';
import '../repositories/promoter_repository.dart';

class CalculateCommission implements UseCase<Commission, CommissionParams> {
  final PromoterRepository repository;
  const CalculateCommission(this.repository);

  @override
  Future<Either<Failure, Commission>> call(CommissionParams params) async {
    final result = await repository.getPromoterById(params.promoterId);
    return result.fold(
      Left.new,
      (promoter) async {
        final commission = Commission(
          id:           const Uuid().v4(),
          promoterId:   promoter.id,
          saleId:       params.saleId,
          saleTotal:    params.saleTotal,
          rate:         promoter.commissionRate,
          amount:       params.saleTotal * promoter.commissionRate / 100,
          calculatedAt: DateTime.now(),
        );
        final save = await repository.recordCommission(commission);
        return save.fold(Left.new, (_) => Right(commission));
      },
    );
  }
}

class CommissionParams extends Equatable {
  final String promoterId;
  final String saleId;
  final double saleTotal;
  const CommissionParams({
    required this.promoterId,
    required this.saleId,
    required this.saleTotal,
  });
  @override
  List<Object> get props => [promoterId, saleId, saleTotal];
}
