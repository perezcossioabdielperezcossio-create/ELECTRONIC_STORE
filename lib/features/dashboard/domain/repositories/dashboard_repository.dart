import '../../../auth/domain/entities/user.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../data/models/financial_metrics_model.dart';
import '../entities/sales_history_entry.dart';

abstract class DashboardRepository {
  Future<BalancePatrimonial> getBalancePatrimonial({String? origenVenta});
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta});
  Future<double> getTotalVentasSemana({DateTime? date, String? usuarioId, String? origenVenta});
  Future<List<Sale>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit});
  Future<List<User>> getSellers();
  Future<List<MetricaCanal>> getMetricasCanal();
  Future<List<SalesHistoryEntry>> getSalesAuditHistory({
    DateTime? date,
    String? usuarioId,
    String? origenVenta,
  });
  Future<List<SalesHistoryEntry>> getAllSalesHistory({
    String? usuarioId,
    String? origenVenta,
  });
}
