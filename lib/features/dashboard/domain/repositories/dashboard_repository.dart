import '../../data/models/financial_metrics_model.dart';

abstract class DashboardRepository {
  Future<BalancePatrimonial> getBalancePatrimonial();
  Future<ArqueoDiario> getArqueoDiario({DateTime? date});
  Future<List<MetricaCanal>> getMetricasCanal();
}
