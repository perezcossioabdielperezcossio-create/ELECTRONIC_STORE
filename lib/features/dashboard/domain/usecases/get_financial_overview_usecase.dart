import '../repositories/dashboard_repository.dart';
import '../../data/models/financial_metrics_model.dart';
import '../../../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';

class GetFinancialOverviewUseCase {
  final DashboardRepository repository;

  GetFinancialOverviewUseCase(this.repository);

  Future<Either<Failure, FinancialOverviewResult>> call({String? origenVenta}) async {
    try {
      final balance = await repository.getBalancePatrimonial(origenVenta: origenVenta);
      final canales = await repository.getMetricasCanal();
      return Right(FinancialOverviewResult(
        balancePatrimonial: balance,
        metricasCanal: canales,
      ));
    } catch (e) {
      return Left(DatabaseFailure('Error obteniendo el balance patrimonial: ${e.toString()}'));
    }
  }
}

class FinancialOverviewResult {
  final BalancePatrimonial balancePatrimonial;
  final List<MetricaCanal> metricasCanal;

  FinancialOverviewResult({
    required this.balancePatrimonial,
    required this.metricasCanal,
  });
}
