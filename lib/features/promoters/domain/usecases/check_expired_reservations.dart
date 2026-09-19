import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/promoter_repository.dart';

class CheckExpiredReservations implements UseCase<Unit, NoParams> {
  final PromoterRepository repository;

  CheckExpiredReservations(this.repository);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    return await repository.checkAndExpireReservations();
  }
}
