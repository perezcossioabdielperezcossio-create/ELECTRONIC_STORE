import 'package:sqflite/sqflite.dart';
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
      query += " AND UPPER(COALESCE(NULLIF(trim(l.location), ''), 'ALMACEN')) = UPPER(?)";
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

  Future<Set<String>> _getTableColumns(Database db, String tableName) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($tableName)');
      return info.map((r) => (r['name'] as String).toLowerCase()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta}) async {
    final db = await dbHelper.database;
    final targetDate = date ?? DateTime.now();
    final dateString = targetDate.toIso8601String().substring(0, 10);

    List<Map<String, dynamic>> desgloseResult = [];
    final salesCols = await _getTableColumns(db, 'sales');
    if (salesCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (salesCols.contains('created_at') && salesCols.contains('fecha_venta')) {
          whereConditions.add("(substr(COALESCE(s.fecha_venta, s.created_at, ''), 1, 10) = ? OR date(COALESCE(s.fecha_venta, s.created_at, 'now')) = date(?))");
          args.addAll([dateString, dateString]);
        } else if (salesCols.contains('fecha_venta')) {
          whereConditions.add("(substr(COALESCE(s.fecha_venta, ''), 1, 10) = ? OR date(COALESCE(s.fecha_venta, 'now')) = date(?))");
          args.addAll([dateString, dateString]);
        } else if (salesCols.contains('created_at')) {
          whereConditions.add("(substr(COALESCE(s.created_at, ''), 1, 10) = ? OR date(COALESCE(s.created_at, 'now')) = date(?))");
          args.addAll([dateString, dateString]);
        }

        if (salesCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(s.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }

        if (usuarioId != null && usuarioId.isNotEmpty) {
          if (salesCols.contains('usuario_id')) {
            whereConditions.add("s.usuario_id = ?");
            args.add(usuarioId);
          } else if (salesCols.contains('promoter_id')) {
            whereConditions.add("s.promoter_id = ?");
            args.add(usuarioId);
          }
        }

        if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado') {
          final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
          if (salesCols.contains('origen_venta') && salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.origen_venta), ''), NULLIF(trim(s.store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }
        }

        final whereClause = whereConditions.isNotEmpty ? "WHERE ${whereConditions.join(" AND ")}" : "";
        final paymentCol = salesCols.contains('payment_method') ? 's.payment_method' : (salesCols.contains('metodo_pago') ? 's.metodo_pago' : "'EFECTIVO'");
        final totalCol = salesCols.contains('total') ? 's.total' : (salesCols.contains('total_cobrado') ? 's.total_cobrado' : '0');

        desgloseResult = await db.rawQuery('''
          SELECT 
            $paymentCol as payment_method,
            SUM($totalCol) as ingreso_bruto,
            SUM(COALESCE(items_cost.total_cost, 0)) as capital_base_recuperado
          FROM sales s
          LEFT JOIN (
            SELECT sale_id, SUM(quantity * unit_cost) as total_cost
            FROM sale_items
            GROUP BY sale_id
          ) items_cost ON s.id = items_cost.sale_id
          $whereClause
          GROUP BY $paymentCol
        ''', args);
      } catch (_) {}
    }

    if (desgloseResult.isEmpty) {
      final ventasCols = await _getTableColumns(db, 'ventas');
      if (ventasCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          if (ventasCols.contains('fecha_venta') && ventasCols.contains('created_at')) {
            whereConditions.add("(substr(COALESCE(s.fecha_venta, s.created_at, ''), 1, 10) = ? OR date(COALESCE(s.fecha_venta, s.created_at, 'now')) = date(?))");
            args.addAll([dateString, dateString]);
          } else if (ventasCols.contains('fecha_venta')) {
            whereConditions.add("(substr(COALESCE(s.fecha_venta, ''), 1, 10) = ? OR date(COALESCE(s.fecha_venta, 'now')) = date(?))");
            args.addAll([dateString, dateString]);
          } else if (ventasCols.contains('created_at')) {
            whereConditions.add("(substr(COALESCE(s.created_at, ''), 1, 10) = ? OR date(COALESCE(s.created_at, 'now')) = date(?))");
            args.addAll([dateString, dateString]);
          }

          if (ventasCols.contains('status')) {
            whereConditions.add("UPPER(COALESCE(s.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
          }

          if (usuarioId != null && usuarioId.isNotEmpty && ventasCols.contains('usuario_id')) {
            whereConditions.add("s.usuario_id = ?");
            args.add(usuarioId);
          }

          if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado' && ventasCols.contains('origen_venta')) {
            final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }

          final whereClause = whereConditions.isNotEmpty ? "WHERE ${whereConditions.join(" AND ")}" : "";
          final paymentCol = ventasCols.contains('metodo_pago') ? 's.metodo_pago' : (ventasCols.contains('payment_method') ? 's.payment_method' : "'EFECTIVO'");
          final totalCol = ventasCols.contains('total_cobrado') ? 's.total_cobrado' : (ventasCols.contains('total') ? 's.total' : '0');

          desgloseResult = await db.rawQuery('''
            SELECT 
              $paymentCol as payment_method,
              SUM($totalCol) as ingreso_bruto,
              SUM(COALESCE(dv_cost.total_cost, 0)) as capital_base_recuperado
            FROM ventas s
            LEFT JOIN (
              SELECT venta_id, SUM(cantidad * costo_unitario_compra) as total_cost
              FROM detalle_ventas
              GROUP BY venta_id
            ) dv_cost ON s.id = dv_cost.venta_id
            $whereClause
            GROUP BY $paymentCol
          ''', args);
        } catch (_) {}
      }
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
    final startOfWeek = DateTime(monday.year, monday.month, monday.day).toIso8601String().substring(0, 10);
    final endOfWeek = DateTime(monday.year, monday.month, monday.day).add(const Duration(days: 6)).toIso8601String().substring(0, 10);

    double total = 0.0;
    final salesCols = await _getTableColumns(db, 'sales');
    if (salesCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        final dateCol = salesCols.contains('created_at') ? 'created_at' : (salesCols.contains('fecha_venta') ? 'fecha_venta' : null);
        if (dateCol != null) {
          whereConditions.add("substr($dateCol, 1, 10) >= ?");
          whereConditions.add("substr($dateCol, 1, 10) <= ?");
          args.addAll([startOfWeek, endOfWeek]);
        }

        if (salesCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }

        if (usuarioId != null && usuarioId.isNotEmpty) {
          if (salesCols.contains('usuario_id')) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          } else if (salesCols.contains('promoter_id')) {
            whereConditions.add("promoter_id = ?");
            args.add(usuarioId);
          }
        }

        if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado') {
          final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
          if (salesCols.contains('origen_venta') && salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), NULLIF(trim(store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }
        }

        final whereClause = whereConditions.isNotEmpty ? "WHERE ${whereConditions.join(" AND ")}" : "";
        final totalCol = salesCols.contains('total') ? 'total' : (salesCols.contains('total_cobrado') ? 'total_cobrado' : '0');

        final res = await db.rawQuery('''
          SELECT SUM($totalCol) as total_semana
          FROM sales
          $whereClause
        ''', args);
        if (res.isNotEmpty && res.first['total_semana'] != null) {
          total = ((res.first['total_semana'] as num?) ?? 0.0).toDouble();
        }
      } catch (_) {}
    }

    if (total == 0.0) {
      final ventasCols = await _getTableColumns(db, 'ventas');
      if (ventasCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          final dateCol = ventasCols.contains('fecha_venta') ? 'fecha_venta' : (ventasCols.contains('created_at') ? 'created_at' : null);
          if (dateCol != null) {
            whereConditions.add("substr($dateCol, 1, 10) >= ?");
            whereConditions.add("substr($dateCol, 1, 10) <= ?");
            args.addAll([startOfWeek, endOfWeek]);
          }

          if (ventasCols.contains('status')) {
            whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
          }

          if (usuarioId != null && usuarioId.isNotEmpty && ventasCols.contains('usuario_id')) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado' && ventasCols.contains('origen_venta')) {
            final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }

          final whereClause = whereConditions.isNotEmpty ? "WHERE ${whereConditions.join(" AND ")}" : "";
          final totalCol = ventasCols.contains('total_cobrado') ? 'total_cobrado' : (ventasCols.contains('total') ? 'total' : '0');

          final res = await db.rawQuery('''
            SELECT SUM($totalCol) as total_semana
            FROM ventas
            $whereClause
          ''', args);
          if (res.isNotEmpty && res.first['total_semana'] != null) {
            total = ((res.first['total_semana'] as num?) ?? 0.0).toDouble();
          }
        } catch (_) {}
      }
    }

    return total;
  }

  @override
  Future<List<SaleModel>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit}) async {
    final db = await dbHelper.database;
    List<Map<String, dynamic>> maps = [];

    final salesCols = await _getTableColumns(db, 'sales');
    if (salesCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (date != null) {
          final dStr = date.toIso8601String().substring(0, 10);
          if (salesCols.contains('created_at') && salesCols.contains('fecha_venta')) {
            whereConditions.add("(substr(COALESCE(created_at, fecha_venta), 1, 10) = ? OR date(COALESCE(created_at, fecha_venta)) = date(?))");
            args.addAll([dStr, dStr]);
          } else if (salesCols.contains('created_at')) {
            whereConditions.add("(substr(created_at, 1, 10) = ? OR date(created_at) = date(?))");
            args.addAll([dStr, dStr]);
          } else if (salesCols.contains('fecha_venta')) {
            whereConditions.add("(substr(fecha_venta, 1, 10) = ? OR date(fecha_venta) = date(?))");
            args.addAll([dStr, dStr]);
          }
        }

        if (salesCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }

        if (usuarioId != null && usuarioId.isNotEmpty) {
          if (salesCols.contains('usuario_id')) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          } else if (salesCols.contains('promoter_id')) {
            whereConditions.add("promoter_id = ?");
            args.add(usuarioId);
          }
        }

        if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado') {
          final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
          if (salesCols.contains('origen_venta') && salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), NULLIF(trim(store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (salesCols.contains('store_location')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(store_location), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }
        }

        final whereStr = whereConditions.isNotEmpty ? whereConditions.join(" AND ") : null;
        final orderByCol = salesCols.contains('created_at') ? 'created_at DESC' : (salesCols.contains('fecha_venta') ? 'fecha_venta DESC' : null);
        maps = await db.query(
          'sales',
          where: whereStr,
          whereArgs: args.isNotEmpty ? args : null,
          orderBy: orderByCol,
          limit: limit,
        );
      } catch (_) {}
    }

    if (maps.isEmpty) {
      final ventasCols = await _getTableColumns(db, 'ventas');
      if (ventasCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          if (date != null) {
            final dStr = date.toIso8601String().substring(0, 10);
            if (ventasCols.contains('fecha_venta') && ventasCols.contains('created_at')) {
              whereConditions.add("(substr(COALESCE(fecha_venta, created_at), 1, 10) = ? OR date(COALESCE(fecha_venta, created_at)) = date(?))");
              args.addAll([dStr, dStr]);
            } else if (ventasCols.contains('fecha_venta')) {
              whereConditions.add("(substr(fecha_venta, 1, 10) = ? OR date(fecha_venta) = date(?))");
              args.addAll([dStr, dStr]);
            } else if (ventasCols.contains('created_at')) {
              whereConditions.add("(substr(created_at, 1, 10) = ? OR date(created_at) = date(?))");
              args.addAll([dStr, dStr]);
            }
          }

          if (ventasCols.contains('status')) {
            whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
          }

          if (usuarioId != null && usuarioId.isNotEmpty && ventasCols.contains('usuario_id')) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado' && ventasCols.contains('origen_venta')) {
            final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          }

          final whereStr = whereConditions.isNotEmpty ? whereConditions.join(" AND ") : null;
          final orderByCol = ventasCols.contains('fecha_venta') ? 'fecha_venta DESC' : (ventasCols.contains('created_at') ? 'created_at DESC' : null);
          maps = await db.query(
            'ventas',
            where: whereStr,
            whereArgs: args.isNotEmpty ? args : null,
            orderBy: orderByCol,
            limit: limit,
          );
        } catch (_) {}
      }
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
