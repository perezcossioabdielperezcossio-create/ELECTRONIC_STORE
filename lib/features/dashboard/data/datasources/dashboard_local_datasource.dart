import '../../../../core/database/database_helper.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../pos/data/models/sale_model.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../../pos/domain/entities/sale_item.dart';
import '../../../pos/data/models/sale_detail_model.dart';
import '../models/financial_metrics_model.dart';

abstract class DashboardLocalDatasource {
  Future<BalancePatrimonial> getBalancePatrimonial({String? origenVenta});
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta});
  Future<double> getTotalVentasSemana({DateTime? date, String? usuarioId, String? origenVenta});
  Future<List<SaleModel>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit});
  Future<List<User>> getSellers();
  Future<List<MetricaCanal>> getMetricasCanal();
}

class DashboardLocalDatasourceImpl implements DashboardLocalDatasource {
  final DatabaseHelper dbHelper;

  DashboardLocalDatasourceImpl(this.dbHelper);

  @override
  Future<BalancePatrimonial> getBalancePatrimonial({String? origenVenta}) async {
    final db = await dbHelper.database;
    String query = '''
      SELECT 
        SUM(l.current_quantity * l.real_unit_cost) AS capital_inmovilizado,
        SUM(l.current_quantity * (COALESCE(p.standard_selling_price, l.real_unit_cost) - l.real_unit_cost)) AS ganancia_potencial
      FROM lots l
      LEFT JOIN products p ON (l.product_id = p.id OR l.product_id = p.sku)
      WHERE (l.is_active = 1 OR l.is_active IS NULL) AND l.current_quantity > 0
    ''';
    final args = <dynamic>[];

    if (origenVenta != null && origenVenta.isNotEmpty) {
      query += " AND UPPER(COALESCE(l.location, 'ALMACEN')) = UPPER(?)";
      args.add(origenVenta);
    }

    final result = await db.rawQuery(query, args);

    if (result.isNotEmpty && result.first['capital_inmovilizado'] != null) {
      final row = result.first;
      return BalancePatrimonial(
        capitalInmovilizado: (row['capital_inmovilizado'] as num).toDouble(),
        gananciaPotencial: ((row['ganancia_potencial'] as num?) ?? 0.0).toDouble(),
      );
    }
    return const BalancePatrimonial(capitalInmovilizado: 0, gananciaPotencial: 0);
  }

  @override
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta}) async {
    final db = await dbHelper.database;
    final targetDate = date ?? DateTime.now();
    final dateString = targetDate.toIso8601String().substring(0, 10);

    List<Map<String, dynamic>> desgloseResult = [];
    try {
      final whereConditions = ["DATE(s.created_at) = ?"];
      final args = <dynamic>[dateString];

      if (usuarioId != null && usuarioId.isNotEmpty) {
        whereConditions.add("s.usuario_id = ?");
        args.add(usuarioId);
      }
      if (origenVenta != null && origenVenta.isNotEmpty) {
        whereConditions.add("UPPER(COALESCE(s.origen_venta, s.store_location, 'ALMACEN')) = UPPER(?)");
        args.add(origenVenta);
      }

      desgloseResult = await db.rawQuery('''
        SELECT 
          s.payment_method as payment_method,
          SUM(s.total) as ingreso_bruto,
          SUM(COALESCE(si.quantity * si.unit_cost, 0)) as capital_base_recuperado
        FROM sales s
        LEFT JOIN sale_items si ON s.id = si.sale_id
        WHERE ${whereConditions.join(" AND ")}
        GROUP BY s.payment_method
      ''', args);
    } catch (_) {}

    if (desgloseResult.isEmpty) {
      try {
        final whereConditions = ["DATE(s.fecha_venta) = ?"];
        final args = <dynamic>[dateString];

        if (usuarioId != null && usuarioId.isNotEmpty) {
          whereConditions.add("s.usuario_id = ?");
          args.add(usuarioId);
        }
        if (origenVenta != null && origenVenta.isNotEmpty) {
          whereConditions.add("UPPER(COALESCE(s.origen_venta, 'ALMACEN')) = UPPER(?)");
          args.add(origenVenta);
        }

        desgloseResult = await db.rawQuery('''
          SELECT 
            s.metodo_pago as payment_method,
            SUM(s.total_cobrado) as ingreso_bruto,
            SUM(COALESCE(dv.cantidad * dv.costo_unitario_compra, 0)) as capital_base_recuperado
          FROM ventas s
          LEFT JOIN detalle_ventas dv ON s.id = dv.venta_id
          WHERE ${whereConditions.join(" AND ")}
          GROUP BY s.metodo_pago
        ''', args);
      } catch (_) {}
    }

    List<DesgloseMetodoPago> desglose = [];
    double ingresoBrutoTotal = 0;
    double capitalBaseRecuperadoTotal = 0;

    for (var row in desgloseResult) {
      final metodo = (row['payment_method'] as String?) ?? 'EFECTIVO';
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
  Future<double> getTotalVentasSemana({DateTime? date, String? usuarioId, String? origenVenta}) async {
    final db = await dbHelper.database;
    final targetDate = date ?? DateTime.now();
    final monday = targetDate.subtract(Duration(days: targetDate.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day).toIso8601String();
    final endOfWeek = DateTime(monday.year, monday.month, monday.day).add(const Duration(days: 7)).toIso8601String();

    double total = 0.0;
    try {
      final whereConditions = ["created_at >= ?", "created_at < ?"];
      final args = <dynamic>[startOfWeek, endOfWeek];

      if (usuarioId != null && usuarioId.isNotEmpty) {
        whereConditions.add("usuario_id = ?");
        args.add(usuarioId);
      }
      if (origenVenta != null && origenVenta.isNotEmpty) {
        whereConditions.add("UPPER(COALESCE(origen_venta, store_location, 'ALMACEN')) = UPPER(?)");
        args.add(origenVenta);
      }

      final res = await db.rawQuery('''
        SELECT SUM(total) as total_semana
        FROM sales
        WHERE ${whereConditions.join(" AND ")}
      ''', args);
      if (res.isNotEmpty && res.first['total_semana'] != null) {
        total = ((res.first['total_semana'] as num?) ?? 0.0).toDouble();
      }
    } catch (_) {}

    if (total == 0.0) {
      try {
        final whereConditions = ["fecha_venta >= ?", "fecha_venta < ?"];
        final args = <dynamic>[startOfWeek, endOfWeek];

        if (usuarioId != null && usuarioId.isNotEmpty) {
          whereConditions.add("usuario_id = ?");
          args.add(usuarioId);
        }
        if (origenVenta != null && origenVenta.isNotEmpty) {
          whereConditions.add("UPPER(COALESCE(origen_venta, 'ALMACEN')) = UPPER(?)");
          args.add(origenVenta);
        }

        final res = await db.rawQuery('''
          SELECT SUM(total_cobrado) as total_semana
          FROM ventas
          WHERE ${whereConditions.join(" AND ")}
        ''', args);
        if (res.isNotEmpty && res.first['total_semana'] != null) {
          total = ((res.first['total_semana'] as num?) ?? 0.0).toDouble();
        }
      } catch (_) {}
    }

    return total;
  }

  @override
  Future<List<SaleModel>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit}) async {
    final db = await dbHelper.database;
    List<Map<String, dynamic>> maps = [];

    try {
      final whereConditions = <String>[];
      final args = <dynamic>[];

      if (date != null) {
        whereConditions.add("DATE(created_at) = ?");
        args.add(date.toIso8601String().substring(0, 10));
      }
      if (usuarioId != null && usuarioId.isNotEmpty) {
        whereConditions.add("usuario_id = ?");
        args.add(usuarioId);
      }
      if (origenVenta != null && origenVenta.isNotEmpty) {
        whereConditions.add("UPPER(COALESCE(origen_venta, store_location, 'ALMACEN')) = UPPER(?)");
        args.add(origenVenta);
      }

      final whereStr = whereConditions.isNotEmpty ? whereConditions.join(" AND ") : null;
      maps = await db.query(
        'sales',
        where: whereStr,
        whereArgs: args.isNotEmpty ? args : null,
        orderBy: 'created_at DESC',
        limit: limit,
      );
    } catch (_) {}

    if (maps.isEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (date != null) {
          whereConditions.add("DATE(fecha_venta) = ?");
          args.add(date.toIso8601String().substring(0, 10));
        }
        if (usuarioId != null && usuarioId.isNotEmpty) {
          whereConditions.add("usuario_id = ?");
          args.add(usuarioId);
        }
        if (origenVenta != null && origenVenta.isNotEmpty) {
          whereConditions.add("UPPER(COALESCE(origen_venta, 'ALMACEN')) = UPPER(?)");
          args.add(origenVenta);
        }

        final whereStr = whereConditions.isNotEmpty ? whereConditions.join(" AND ") : null;
        maps = await db.query(
          'ventas',
          where: whereStr,
          whereArgs: args.isNotEmpty ? args : null,
          orderBy: 'fecha_venta DESC',
          limit: limit,
        );
      } catch (_) {}
    }

    final sales = <SaleModel>[];
    for (final m in maps) {
      final saleId = (m['id'] as String?) ?? '';
      final details = <SaleDetail>[];
      try {
        final detailsMaps = await db.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [saleId]);
        for (final dm in detailsMaps) {
          details.add(SaleDetailModel.fromMap(dm));
        }
      } catch (_) {}

      final items = <SaleItem>[];
      try {
        final itemsMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final im in itemsMaps) {
          items.add(SaleItem(
            productId: im['product_id'] as String,
            productName: (im['product_name'] as String?) ?? '',
            quantity: (im['quantity'] as num).toInt(),
            unitPrice: (im['unit_price'] as num).toDouble(),
            unitCost: (im['unit_cost'] as num?)?.toDouble() ?? 0.0,
            lineDiscount: (im['line_discount'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      } catch (_) {}

      sales.add(SaleModel.fromMap(m, items: items, details: details));
    }
    return sales;
  }

  @override
  Future<List<User>> getSellers() async {
    final db = await dbHelper.database;
    final sellers = <User>[];

    try {
      final rows = await db.rawQuery('''
        SELECT DISTINCT celular, nombre, pin, role, tienda_nombre, activo
        FROM usuarios
        WHERE role = 'seller'
      ''');
      for (final r in rows) {
        sellers.add(User(
          celular: (r['celular'] as String?) ?? '',
          nombre: (r['nombre'] as String?) ?? '',
          pin: (r['pin'] as String?) ?? '',
          role: UserRole.seller,
          tiendaNombre: (r['tienda_nombre'] as String?) ?? 'Tienda Física',
          activo: (r['activo'] as int?) == 1,
        ));
      }
    } catch (_) {}

    return sellers;
  }

  @override
  Future<List<MetricaCanal>> getMetricasCanal() async {
    final db = await dbHelper.database;
    List<Map<String, dynamic>> result = [];

    try {
      result = await db.rawQuery('''
        SELECT 
          CASE WHEN s.promoter_id IS NULL THEN 'Venta Directa' ELSE 'Red de Promotores' END as canal,
          SUM(s.total) as total_ingresos,
          SUM(si.quantity * si.unit_cost) as total_costos
        FROM sales s
        JOIN sale_items si ON s.id = si.sale_id
        GROUP BY CASE WHEN s.promoter_id IS NULL THEN 'Venta Directa' ELSE 'Red de Promotores' END
      ''');
    } catch (_) {}

    if (result.isEmpty) {
      try {
        result = await db.rawQuery('''
          SELECT 
            'Venta Directa' as canal,
            SUM(v.total_cobrado) as total_ingresos,
            SUM(dv.cantidad * dv.costo_unitario_compra) as total_costos
          FROM ventas v
          JOIN detalle_ventas dv ON v.id = dv.venta_id
          GROUP BY 'Venta Directa'
        ''');
      } catch (_) {}
    }

    return result.map((row) {
      return MetricaCanal(
        canal: row['canal'] as String,
        totalIngresos: (row['total_ingresos'] as num?)?.toDouble() ?? 0.0,
        totalCostos: (row['total_costos'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }
}
