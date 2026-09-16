import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.todaySales,
    required super.transactionCount,
    required super.lowStockCount,
    required super.pendingCommissions,
  });
}
