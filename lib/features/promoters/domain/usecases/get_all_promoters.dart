import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/promoter.dart';
import '../repositories/promoter_repository.dart';

class GetAllPromoters implements UseCase<List<Promoter>, NoParams> {
  final PromoterRepository repository;
  const GetAllPromoters(this.repository);

  @override
  Future<Either<Failure, List<Promoter>>> call(NoParams params) =>
      repository.getAllPromoters();
}
