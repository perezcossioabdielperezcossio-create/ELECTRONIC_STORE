import '../../../auth/domain/entities/user.dart';
import '../../../pos/domain/entities/sale.dart';
import '../models/financial_metrics_model.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDatasource localDatasource;

  DashboardRepositoryImpl(this.localDatasource);

  @override
  Future<BalancePatrimonial> getBalancePatrimonial({String? origenVenta}) async {
    return await localDatasource.getBalancePatrimonial(origenVenta: origenVenta);
  }

  @override
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta}) async {
    return await localDatasource.getArqueoDiario(date: date, usuarioId: usuarioId, origenVenta: origenVenta);
  }

  @override
  Future<double> getTotalVentasSemana({DateTime? date, String? usuarioId, String? origenVenta}) async {
    return await localDatasource.getTotalVentasSemana(date: date, usuarioId: usuarioId, origenVenta: origenVenta);
  }

  @override
  Future<List<Sale>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit}) async {
    return await localDatasource.getVentasFiltradas(date: date, usuarioId: usuarioId, origenVenta: origenVenta, limit: limit);
  }

  @override
  Future<List<User>> getSellers() async {
    return await localDatasource.getSellers();
  }

  @override
  Future<List<MetricaCanal>> getMetricasCanal() async {
    return await localDatasource.getMetricasCanal();
  }
}
