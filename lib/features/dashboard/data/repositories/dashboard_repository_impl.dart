import '../models/financial_metrics_model.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDatasource localDatasource;

  DashboardRepositoryImpl(this.localDatasource);

  @override
  Future<BalancePatrimonial> getBalancePatrimonial() async {
    return await localDatasource.getBalancePatrimonial();
  }

  @override
  Future<ArqueoDiario> getArqueoDiario({DateTime? date}) async {
    return await localDatasource.getArqueoDiario(date: date);
  }

  @override
  Future<List<MetricaCanal>> getMetricasCanal() async {
    return await localDatasource.getMetricasCanal();
  }
}
