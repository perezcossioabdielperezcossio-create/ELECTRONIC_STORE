import '../../../../core/database/database_helper.dart';
import '../models/financial_metrics_model.dart';

abstract class DashboardLocalDatasource {
  Future<BalancePatrimonial> getBalancePatrimonial();
  Future<ArqueoDiario> getArqueoDiario({DateTime? date});
  Future<List<MetricaCanal>> getMetricasCanal();
}

class DashboardLocalDatasourceImpl implements DashboardLocalDatasource {
  final DatabaseHelper dbHelper;

  DashboardLocalDatasourceImpl(this.dbHelper);

  @override
  Future<BalancePatrimonial> getBalancePatrimonial() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(l.current_quantity * l.real_unit_cost) AS capital_inmovilizado,
        SUM(l.current_quantity * (p.standard_selling_price - l.real_unit_cost)) AS ganancia_potencial
      FROM lots l
      JOIN products p ON l.product_id = p.id
      WHERE l.is_active = 1
    ''');

    if (result.isNotEmpty && result.first['capital_inmovilizado'] != null) {
      final row = result.first;
      return BalancePatrimonial(
        capitalInmovilizado: (row['capital_inmovilizado'] as num).toDouble(),
        gananciaPotencial: (row['ganancia_potencial'] as num).toDouble(),
      );
    }
    return const BalancePatrimonial(capitalInmovilizado: 0, gananciaPotencial: 0);
  }

  @override
  Future<ArqueoDiario> getArqueoDiario({DateTime? date}) async {
    final db = await dbHelper.database;
    final targetDate = date ?? DateTime.now();
    final dateString = targetDate.toIso8601String().substring(0, 10);

    final desgloseResult = await db.rawQuery('''
      SELECT 
        s.payment_method,
        SUM(s.total) as ingreso_bruto,
        SUM(si.quantity * si.unit_cost) as capital_base_recuperado
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      WHERE DATE(s.created_at) = ?
      GROUP BY s.payment_method
    ''', [dateString]);

    List<DesgloseMetodoPago> desglose = [];
    double ingresoBrutoTotal = 0;
    double capitalBaseRecuperadoTotal = 0;

    for (var row in desgloseResult) {
      final metodo = row['payment_method'] as String;
      final ingreso = (row['ingreso_bruto'] as num?)?.toDouble() ?? 0.0;
      final capitalRecuperado = (row['capital_base_recuperado'] as num?)?.toDouble() ?? 0.0;

      desglose.add(DesgloseMetodoPago(
        metodo: metodo,
        ingresoBruto: ingreso,
        capitalBaseRecuperado: capitalRecuperado,
      ));

      ingresoBrutoTotal += ingreso;
      capitalBaseRecuperadoTotal += capitalRecuperado;
    }

    return ArqueoDiario(
      fecha: targetDate,
      ingresoBrutoTotal: ingresoBrutoTotal,
      capitalBaseRecuperadoTotal: capitalBaseRecuperadoTotal,
      desglose: desglose,
    );
  }

  @override
  Future<List<MetricaCanal>> getMetricasCanal() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        CASE WHEN s.promoter_id IS NULL THEN 'Venta Directa' ELSE 'Red de Promotores' END as canal,
        SUM(s.total) as total_ingresos,
        SUM(si.quantity * si.unit_cost) as total_costos
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      GROUP BY CASE WHEN s.promoter_id IS NULL THEN 'Venta Directa' ELSE 'Red de Promotores' END
    ''');

    return result.map((row) {
      return MetricaCanal(
        canal: row['canal'] as String,
        totalIngresos: (row['total_ingresos'] as num?)?.toDouble() ?? 0.0,
        totalCostos: (row['total_costos'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }
}
