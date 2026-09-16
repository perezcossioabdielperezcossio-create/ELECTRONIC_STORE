import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummary implements UseCase<DashboardSummary, DashboardParams> {
  final DashboardRepository repository;
  const GetDashboardSummary(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call(DashboardParams params) =>
      repository.getSummary(params.date);
}

class DashboardParams extends Equatable {
  final DateTime date;
  const DashboardParams(this.date);
  @override
  List<Object> get props => [date];
}
