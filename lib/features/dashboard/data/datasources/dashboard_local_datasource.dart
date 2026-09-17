import '../../../../core/database/database_helper.dart';
import '../models/dashboard_summary_model.dart';

abstract class DashboardLocalDatasource {
  Future<DashboardSummaryModel> getSummary(DateTime date);
}

class DashboardLocalDatasourceImpl implements DashboardLocalDatasource {
  final DatabaseHelper dbHelper;
  const DashboardLocalDatasourceImpl(this.dbHelper);

  @override
  Future<DashboardSummaryModel> getSummary(DateTime date) async {
    final db    = await dbHelper.database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end   = DateTime(date.year, date.month, date.day + 1).toIso8601String();

    final salesResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total),0) as total, COUNT(*) as cnt "
      "FROM sales WHERE created_at >= ? AND created_at < ? AND status = 'completed'",
      [start, end],
    );

    final lowStock = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM (SELECT product_id, SUM(quantity) as q "
      "FROM inventory_batches GROUP BY product_id HAVING q <= 5)",
    );

    final row = salesResult.first;
    return DashboardSummaryModel(
      todaySales:          (row['total'] as num).toDouble(),
      transactionCount:    row['cnt'] as int,
      lowStockCount:       lowStock.first['cnt'] as int,
      pendingCommissions:  0, // TODO: query commissions table
    );
  }
}
