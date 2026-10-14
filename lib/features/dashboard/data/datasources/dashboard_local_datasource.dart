import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/data/models/sale_model.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../../pos/domain/entities/sale_item.dart';
import '../../../pos/data/models/sale_detail_model.dart';
import '../models/financial_metrics_model.dart';
import '../../domain/entities/sales_history_entry.dart';

abstract class DashboardLocalDatasource {
  Future<BalancePatrimonial> getBalancePatrimonial({String? origenVenta});
  Future<ArqueoDiario> getArqueoDiario({DateTime? date, String? usuarioId, String? origenVenta});
  Future<double> getTotalVentasSemana({DateTime? date, String? usuarioId, String? origenVenta});
  Future<List<SaleModel>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit});
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
    final isSellerQuery = origenVenta == 'TIENDA' || (usuarioId != null && usuarioId.isNotEmpty && origenVenta != 'ALMACEN');

    if (isSellerQuery) {
      final vvCols = await _getTableColumns(db, 'ventas_vendedor');
      if (vvCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          whereConditions.add("(substr(fecha_venta, 1, 10) = ? OR date(fecha_venta) = date(?))");
          args.addAll([dateString, dateString]);

          whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");

          if (usuarioId != null && usuarioId.isNotEmpty) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          final whereClause = "WHERE ${whereConditions.join(" AND ")}";
          desgloseResult = await db.rawQuery('''
            SELECT 
              metodo_pago as payment_method,
              SUM(total_cobrado) as ingreso_bruto,
              0.0 as capital_base_recuperado
            FROM ventas_vendedor
            $whereClause
            GROUP BY metodo_pago
          ''', args);
        } catch (_) {}
      }
    } else {
      // Regla 2: Dashboard de Almacén calcula métricas y arqueos consultando EXCLUSIVAMENTE la tabla ventas (origen_venta = 'ALMACEN')
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

          if (ventasCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
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

    // Fallback para datos de pruebas heredadas donde solo se pobló la tabla sales/ventas
    if (!isSellerQuery && desgloseResult.isEmpty) {
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
            }
          }

          if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado') {
            final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
            if (salesCols.contains('origen_venta')) {
              whereConditions.add("UPPER(COALESCE(NULLIF(trim(s.origen_venta), ''), 'ALMACEN')) = UPPER(?)");
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
    final isSellerQuery = origenVenta == 'TIENDA' || (usuarioId != null && usuarioId.isNotEmpty && origenVenta != 'ALMACEN');

    if (isSellerQuery) {
      final vvCols = await _getTableColumns(db, 'ventas_vendedor');
      if (vvCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          whereConditions.add("substr(fecha_venta, 1, 10) >= ?");
          whereConditions.add("substr(fecha_venta, 1, 10) <= ?");
          args.addAll([startOfWeek, endOfWeek]);

          whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");

          if (usuarioId != null && usuarioId.isNotEmpty) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          final whereClause = "WHERE ${whereConditions.join(" AND ")}";
          final res = await db.rawQuery('''
            SELECT SUM(total_cobrado) as total_semana
            FROM ventas_vendedor
            $whereClause
          ''', args);
          if (res.isNotEmpty && res.first['total_semana'] != null) {
            return ((res.first['total_semana'] as num?) ?? 0.0).toDouble();
          }
        } catch (_) {}
      }
      return 0.0;
    } else {
      // Regla 2: Dashboard de Almacén calcula consultando EXCLUSIVAMENTE la tabla ventas (origen_venta = 'ALMACEN')
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

          if (ventasCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
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
            return total;
          }
        } catch (_) {}
      }
    }

    // Fallback para pruebas con tabla sales / ventas
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

        if (usuarioId != null && usuarioId.isNotEmpty && salesCols.contains('usuario_id')) {
          whereConditions.add("usuario_id = ?");
          args.add(usuarioId);
        }

        if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado' && salesCols.contains('origen_venta')) {
          final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
          whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
          args.add(filter);
        } else if (!isSellerQuery && salesCols.contains('origen_venta')) {
          whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
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

    return total;
  }

  @override
  Future<List<SaleModel>> getVentasFiltradas({DateTime? date, String? usuarioId, String? origenVenta, int? limit}) async {
    final db = await dbHelper.database;
    List<Map<String, dynamic>> maps = [];
    final isSellerQuery = origenVenta == 'TIENDA' || (usuarioId != null && usuarioId.isNotEmpty && origenVenta != 'ALMACEN');

    if (isSellerQuery) {
      final vvCols = await _getTableColumns(db, 'ventas_vendedor');
      if (vvCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          if (date != null) {
            final dStr = date.toIso8601String().substring(0, 10);
            whereConditions.add("(substr(fecha_venta, 1, 10) = ? OR date(fecha_venta) = date(?))");
            args.addAll([dStr, dStr]);
          }

          whereConditions.add("UPPER(COALESCE(status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");

          if (usuarioId != null && usuarioId.isNotEmpty) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          final whereStr = whereConditions.isNotEmpty ? whereConditions.join(" AND ") : null;
          maps = await db.query(
            'ventas_vendedor',
            where: whereStr,
            whereArgs: args.isNotEmpty ? args : null,
            orderBy: 'fecha_venta DESC',
            limit: limit,
          );

          if (maps.isNotEmpty) {
            final sales = <SaleModel>[];
            for (final m in maps) {
              List<SaleItem> sellerItems = [];
              final rawItems = m['items'];
              if (rawItems is String) {
                try {
                  final decoded = jsonDecode(rawItems);
                  if (decoded is List) {
                    sellerItems = decoded.map((i) => SaleItem(
                      productId: (i['product_id'] ?? '').toString(),
                      productName: (i['product_name'] ?? '').toString(),
                      quantity: (i['cantidad'] as num?)?.toInt() ?? 1,
                      unitPrice: (i['precio_unitario'] as num?)?.toDouble() ?? 0.0,
                    )).toList();
                  }
                } catch (_) {}
              }
              sales.add(SaleModel(
                id: (m['id'] ?? '').toString(),
                usuarioId: m['usuario_id']?.toString(),
                vendedorNombre: m['vendedor_nombre']?.toString(),
                customerName: m['cliente_nombre']?.toString() ?? 'Cliente Mostrador',
                createdAt: DateTime.tryParse(m['fecha_venta']?.toString() ?? '') ?? DateTime.now(),
                items: sellerItems,
                paymentMethod: m['metodo_pago']?.toString() ?? 'EFECTIVO',
                deliveryMethod: 'TIENDA',
                storeLocation: 'TIENDA',
                status: SaleStatus.completed,
                isLocked: true,
              ));
            }
            return sales;
          }
        } catch (_) {}
      }
      return [];
    } else {
      // Regla 2: Dashboard de Almacén consulta EXCLUSIVAMENTE ventas (origen_venta = 'ALMACEN')
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

          if (ventasCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
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

    // Fallback si ventas/ventas_vendedor estaba vacía pero sales tiene registros (para tests mock antiguos)
    if (!isSellerQuery && maps.isEmpty) {
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

          if (usuarioId != null && usuarioId.isNotEmpty && salesCols.contains('usuario_id')) {
            whereConditions.add("usuario_id = ?");
            args.add(usuarioId);
          }

          if (origenVenta != null && origenVenta.isNotEmpty && origenVenta != 'Consolidado' && salesCols.contains('origen_venta')) {
            final filter = origenVenta == 'Almacén Central' ? 'ALMACEN' : origenVenta;
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = UPPER(?)");
            args.add(filter);
          } else if (!isSellerQuery && salesCols.contains('origen_venta')) {
            whereConditions.add("UPPER(COALESCE(NULLIF(trim(origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
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

  @override
  Future<List<SalesHistoryEntry>> getSalesAuditHistory({
    DateTime? date,
    String? usuarioId,
    String? origenVenta,
  }) async {
    final db = await dbHelper.database;
    final entries = <SalesHistoryEntry>[];
    final isSellerQuery =
        origenVenta == 'TIENDA' || (usuarioId != null && usuarioId.isNotEmpty && origenVenta != 'ALMACEN');

    if (isSellerQuery) {
      // Ventas de Tienda: tabla ventas_vendedor (items en columna JSON)
      final vvCols = await _getTableColumns(db, 'ventas_vendedor');
      if (vvCols.isNotEmpty) {
        try {
          final whereConditions = <String>[];
          final args = <dynamic>[];

          if (date != null) {
            final dStr = date.toIso8601String().substring(0, 10);
            whereConditions.add("(substr(vv.fecha_venta, 1, 10) = ? OR date(vv.fecha_venta) = date(?))");
            args.addAll([dStr, dStr]);
          }
          whereConditions.add("UPPER(COALESCE(vv.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
          if (usuarioId != null && usuarioId.isNotEmpty) {
            whereConditions.add('vv.usuario_id = ?');
            args.add(usuarioId);
          }

          final whereClause =
              whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';

          final rows = await db.rawQuery('''
            SELECT
              vv.id            AS venta_id,
              vv.fecha_venta   AS fecha,
              vv.metodo_pago,
              'TIENDA'         AS tipo_entrega,
              vv.usuario_id,
              NULL             AS cliente_id,
              COALESCE(vv.cliente_nombre, 'Mostrador') AS cliente_nombre,
              vv.items         AS items_json
            FROM ventas_vendedor vv
            $whereClause
            ORDER BY vv.fecha_venta DESC
          ''', args);

          for (final row in rows) {
            final ventaId = (row['venta_id'] ?? '').toString();
            final fecha =
                DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now();
            final metodoPago = (row['metodo_pago'] as String?) ?? 'EFECTIVO';
            final clienteNombre = (row['cliente_nombre'] as String?) ?? 'Mostrador';
            final rowUsuarioId = row['usuario_id'] as String?;

            // Expand the JSON items array into individual entries
            final rawItems = row['items_json'];
            if (rawItems is String && rawItems.isNotEmpty) {
              try {
                final decoded = jsonDecode(rawItems);
                if (decoded is List) {
                  for (final item in decoded) {
                    final cantidad =
                        (item['cantidad'] as num?)?.toInt() ?? 1;
                    final precioUnit =
                        (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                    entries.add(SalesHistoryEntry(
                      ventaId: ventaId,
                      fecha: fecha,
                      metodoPago: metodoPago,
                      tipoEntrega: 'TIENDA',
                      usuarioId: rowUsuarioId,
                      clienteNombre: clienteNombre,
                      detalleId: '${ventaId}_${item['product_id'] ?? ''}',
                      productId: (item['product_id'] ?? '').toString(),
                      productName: (item['product_name'] ?? '').toString(),
                      sku: item['sku']?.toString(),
                      cantidad: cantidad,
                      costoUnitario: 0.0, // no cost tracked in seller JSON
                      precioUnitario: precioUnit,
                    ));
                  }
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
      return entries;
    }

    // ── Ventas de Almacén (o Consolidado): JOIN ventas × detalle_ventas × products ──
    final ventasCols = await _getTableColumns(db, 'ventas');
    final detalleCols = await _getTableColumns(db, 'detalle_ventas');

    if (ventasCols.isNotEmpty && detalleCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (date != null) {
          final dStr = date.toIso8601String().substring(0, 10);
          if (ventasCols.contains('fecha_venta') && ventasCols.contains('created_at')) {
            whereConditions.add(
                "(substr(COALESCE(v.fecha_venta, v.created_at, ''), 1, 10) = ? "
                "OR date(COALESCE(v.fecha_venta, v.created_at, 'now')) = date(?))");
          } else if (ventasCols.contains('fecha_venta')) {
            whereConditions
                .add("(substr(v.fecha_venta, 1, 10) = ? OR date(v.fecha_venta) = date(?))");
          } else {
            whereConditions
                .add("(substr(v.created_at, 1, 10) = ? OR date(v.created_at) = date(?))");
          }
          args.addAll([dStr, dStr]);
        }

        if (ventasCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(v.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }
        if (ventasCols.contains('origen_venta') && origenVenta == 'ALMACEN') {
          whereConditions
              .add("UPPER(COALESCE(NULLIF(trim(v.origen_venta), ''), 'ALMACEN')) = 'ALMACEN'");
        }

        final whereClause =
            whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';

        final dateCol = ventasCols.contains('fecha_venta') && ventasCols.contains('created_at')
            ? 'COALESCE(v.fecha_venta, v.created_at)'
            : ventasCols.contains('fecha_venta')
                ? 'v.fecha_venta'
                : 'v.created_at';

        final clienteExpr = ventasCols.contains('cliente_nombre') && ventasCols.contains('customer_name')
            ? "COALESCE(v.cliente_nombre, v.customer_name, 'Mostrador')"
            : ventasCols.contains('cliente_nombre')
                ? "COALESCE(v.cliente_nombre, 'Mostrador')"
                : ventasCols.contains('customer_name')
                    ? "COALESCE(v.customer_name, 'Mostrador')"
                    : "'Mostrador'";

        final prodIdCol = detalleCols.contains('product_id')
            ? 'dv.product_id'
            : (detalleCols.contains('producto_id') ? 'dv.producto_id' : "''");

        final prodNameExpr = detalleCols.contains('product_name')
            ? "COALESCE(p.name, dv.product_name, 'Venta General')"
            : "COALESCE(p.name, 'Venta General')";

        final costCol = detalleCols.contains('costo_unitario_compra')
            ? 'dv.costo_unitario_compra'
            : (detalleCols.contains('unit_cost') ? 'COALESCE(dv.unit_cost, 0.0)' : '0.0');

        final priceCol = detalleCols.contains('precio_unitario_cobrado')
            ? 'dv.precio_unitario_cobrado'
            : (detalleCols.contains('unit_price') ? 'COALESCE(dv.unit_price, 0.0)' : 'NULL');

        final discountCol = detalleCols.contains('line_discount')
            ? 'COALESCE(dv.line_discount, 0.0)'
            : (detalleCols.contains('descuento_linea') ? 'COALESCE(dv.descuento_linea, 0.0)' : '0.0');

        final rows = await db.rawQuery('''
          SELECT
            v.id                                                AS venta_id,
            $dateCol                                            AS fecha,
            COALESCE(v.metodo_pago, 'EFECTIVO')                AS metodo_pago,
            COALESCE(v.tipo_entrega, 'MOSTRADOR')              AS tipo_entrega,
            ${ventasCols.contains('usuario_id') ? 'v.usuario_id' : 'NULL'} AS usuario_id,
            ${ventasCols.contains('cliente_id') ? 'v.cliente_id' : 'NULL'} AS cliente_id,
            $clienteExpr                                       AS cliente_nombre,
            COALESCE(v.total_cobrado, 0.0)                     AS total_venta,
            COALESCE(dv.id, v.id || '_det')                    AS detalle_id,
            COALESCE($prodIdCol, '')                           AS product_id,
            $prodNameExpr                                      AS product_name,
            COALESCE(p.sku, '-')                               AS sku,
            COALESCE(dv.cantidad, 1)                           AS cantidad,
            COALESCE($costCol, 0.0)                            AS precio_compra,
            COALESCE($costCol, 0.0)                            AS costo_unitario,
            COALESCE($priceCol, v.total_cobrado, 0.0)          AS precio_venta,
            COALESCE($priceCol, v.total_cobrado, 0.0)          AS precio_unitario,
            COALESCE((COALESCE($priceCol, v.total_cobrado, 0.0) - COALESCE($costCol, 0.0)) * COALESCE(dv.cantidad, 1), 0.0) AS ganancia_neta,
            $discountCol                                       AS line_discount
          FROM ventas v
          LEFT JOIN detalle_ventas dv ON v.id = dv.venta_id
          LEFT JOIN products p ON ($prodIdCol = p.id OR (p.sku = $prodIdCol AND $prodIdCol != ''))
          $whereClause
          ORDER BY $dateCol DESC
        ''', args);

        for (final row in rows) {
          final fecha = DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now();
          final totalVenta = (row['total_venta'] as num?)?.toDouble() ?? 0.0;
          final precioUnit = (row['precio_venta'] as num?)?.toDouble() ??
              (row['precio_unitario'] as num?)?.toDouble() ??
              totalVenta;
          final costoUnit = (row['precio_compra'] as num?)?.toDouble() ??
              (row['costo_unitario'] as num?)?.toDouble() ??
              0.0;

          entries.add(SalesHistoryEntry(
            ventaId: (row['venta_id'] ?? '').toString(),
            fecha: fecha,
            metodoPago: (row['metodo_pago'] as String?) ?? 'EFECTIVO',
            tipoEntrega: (row['tipo_entrega'] as String?) ?? 'MOSTRADOR',
            usuarioId: row['usuario_id'] as String?,
            clienteId: row['cliente_id'] as String?,
            clienteNombre: (row['cliente_nombre'] as String?) ?? 'Mostrador',
            detalleId: (row['detalle_id'] ?? '${row['venta_id']}_det').toString(),
            productId: (row['product_id'] ?? '').toString(),
            productName: (row['product_name'] ?? 'Venta General').toString(),
            sku: (row['sku'] as String?) ?? '-',
            cantidad: (row['cantidad'] as num?)?.toInt() ?? 1,
            costoUnitario: costoUnit,
            precioUnitario: precioUnit,
            lineDiscount: (row['line_discount'] as num?)?.toDouble() ?? 0.0,
          ));
        }
        return entries;
      } catch (_) {}
    }

    // ── Fallback: tabla sales / sale_items (tests heredados) ──
    final salesCols = await _getTableColumns(db, 'sales');
    final itemsCols = await _getTableColumns(db, 'sale_items');
    if (salesCols.isNotEmpty && itemsCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (date != null) {
          final dStr = date.toIso8601String().substring(0, 10);
          if (salesCols.contains('created_at') && salesCols.contains('fecha_venta')) {
            whereConditions.add(
                "(substr(COALESCE(s.created_at, s.fecha_venta, ''), 1, 10) = ? "
                "OR date(COALESCE(s.created_at, s.fecha_venta, 'now')) = date(?))");
          } else if (salesCols.contains('created_at')) {
            whereConditions
                .add("(substr(s.created_at, 1, 10) = ? OR date(s.created_at) = date(?))");
          } else {
            whereConditions
                .add("(substr(s.fecha_venta, 1, 10) = ? OR date(s.fecha_venta) = date(?))");
          }
          args.addAll([dStr, dStr]);
        }

        if (salesCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(s.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }

        final whereClause =
            whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';

        final dateCol =
            salesCols.contains('created_at') ? 's.created_at' : 's.fecha_venta';
        final paymentCol =
            salesCols.contains('payment_method') ? 's.payment_method' : "'EFECTIVO'";

        final rows = await db.rawQuery('''
          SELECT
            s.id                                  AS venta_id,
            $dateCol                              AS fecha,
            $paymentCol                           AS metodo_pago,
            'MOSTRADOR'                           AS tipo_entrega,
            NULL                                  AS usuario_id,
            NULL                                  AS cliente_id,
            'Mostrador'                           AS cliente_nombre,
            COALESCE(si.id, s.id || '_item')      AS detalle_id,
            COALESCE(si.product_id, '')           AS product_id,
            COALESCE(p.name, si.product_id, 'Venta General') AS product_name,
            COALESCE(p.sku, '-')                  AS sku,
            COALESCE(si.quantity, 1)              AS cantidad,
            COALESCE(si.unit_cost, 0.0)           AS costo_unitario,
            COALESCE(si.unit_price, s.total, 0.0) AS precio_unitario,
            0.0                                   AS line_discount
          FROM sales s
          LEFT JOIN sale_items si ON si.sale_id = s.id
          LEFT JOIN products p ON p.id = si.product_id
          $whereClause
          ORDER BY $dateCol DESC
        ''', args);

        for (final row in rows) {
          final fecha = DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now();
          entries.add(SalesHistoryEntry(
            ventaId: (row['venta_id'] ?? '').toString(),
            fecha: fecha,
            metodoPago: (row['metodo_pago'] as String?) ?? 'EFECTIVO',
            tipoEntrega: 'MOSTRADOR',
            clienteNombre: 'Mostrador',
            detalleId: (row['detalle_id'] ?? '').toString(),
            productId: (row['product_id'] ?? '').toString(),
            productName: (row['product_name'] ?? '').toString(),
            sku: row['sku'] as String?,
            cantidad: (row['cantidad'] as num?)?.toInt() ?? 1,
            costoUnitario: (row['costo_unitario'] as num?)?.toDouble() ?? 0.0,
            precioUnitario: (row['precio_unitario'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      } catch (_) {}
    }

    return entries;
  }

  @override
  Future<List<SalesHistoryEntry>> getAllSalesHistory({
    String? usuarioId,
    String? origenVenta,
  }) async {
    final db = await dbHelper.database;
    final entries = <SalesHistoryEntry>[];

    // Si es auditoría de vendedor por tienda, consultar ventas_vendedor
    if (origenVenta == 'TIENDA' || (usuarioId != null && usuarioId.isNotEmpty && origenVenta != 'ALMACEN')) {
      return getSalesAuditHistory(date: null, usuarioId: usuarioId, origenVenta: origenVenta);
    }

    final ventasCols = await _getTableColumns(db, 'ventas');
    final detalleCols = await _getTableColumns(db, 'detalle_ventas');

    if (ventasCols.isNotEmpty && detalleCols.isNotEmpty) {
      try {
        final whereConditions = <String>[];
        final args = <dynamic>[];

        if (ventasCols.contains('status')) {
          whereConditions.add("UPPER(COALESCE(v.status, 'COMPLETED')) NOT IN ('VOIDED', 'ANULADA')");
        }

        final whereClause = whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';

        final dateCol = ventasCols.contains('fecha_venta') && ventasCols.contains('created_at')
            ? 'COALESCE(v.fecha_venta, v.created_at)'
            : ventasCols.contains('fecha_venta')
                ? 'v.fecha_venta'
                : 'v.created_at';

        final clienteExpr = ventasCols.contains('cliente_nombre') && ventasCols.contains('customer_name')
            ? "COALESCE(v.cliente_nombre, v.customer_name, 'Cliente Mostrador')"
            : ventasCols.contains('cliente_nombre')
                ? "COALESCE(v.cliente_nombre, 'Cliente Mostrador')"
                : ventasCols.contains('customer_name')
                    ? "COALESCE(v.customer_name, 'Cliente Mostrador')"
                    : "'Cliente Mostrador'";

        final prodIdCol = detalleCols.contains('product_id')
            ? 'dv.product_id'
            : (detalleCols.contains('producto_id') ? 'dv.producto_id' : "''");

        final prodNameExpr = detalleCols.contains('product_name')
            ? "COALESCE(p.name, dv.product_name, 'Venta General')"
            : "COALESCE(p.name, 'Venta General')";

        final costCol = detalleCols.contains('costo_unitario_compra')
            ? 'dv.costo_unitario_compra'
            : (detalleCols.contains('unit_cost') ? 'COALESCE(dv.unit_cost, 0.0)' : '0.0');

        final priceCol = detalleCols.contains('precio_unitario_cobrado')
            ? 'dv.precio_unitario_cobrado'
            : (detalleCols.contains('unit_price') ? 'COALESCE(dv.unit_price, 0.0)' : 'NULL');

        final discountCol = detalleCols.contains('line_discount')
            ? 'COALESCE(dv.line_discount, 0.0)'
            : (detalleCols.contains('descuento_linea') ? 'COALESCE(dv.descuento_linea, 0.0)' : '0.0');

        final rows = await db.rawQuery('''
          SELECT
            v.id                                                AS venta_id,
            $dateCol                                            AS fecha,
            COALESCE(v.metodo_pago, 'EFECTIVO')                AS metodo_pago,
            COALESCE(v.tipo_entrega, 'MOSTRADOR')              AS tipo_entrega,
            ${ventasCols.contains('usuario_id') ? 'v.usuario_id' : 'NULL'} AS usuario_id,
            ${ventasCols.contains('cliente_id') ? 'v.cliente_id' : 'NULL'} AS cliente_id,
            $clienteExpr                                       AS cliente_nombre,
            COALESCE(v.total_cobrado, 0.0)                     AS total_venta,
            COALESCE(dv.id, v.id || '_det')                    AS detalle_id,
            COALESCE($prodIdCol, '')                           AS product_id,
            $prodNameExpr                                      AS product_name,
            COALESCE(p.sku, '-')                               AS sku,
            COALESCE(dv.cantidad, 1)                           AS cantidad,
            COALESCE($costCol, 0.0)                            AS precio_compra,
            COALESCE($costCol, 0.0)                            AS costo_unitario,
            COALESCE($priceCol, v.total_cobrado, 0.0)          AS precio_venta,
            COALESCE($priceCol, v.total_cobrado, 0.0)          AS precio_unitario,
            COALESCE((COALESCE($priceCol, v.total_cobrado, 0.0) - COALESCE($costCol, 0.0)) * COALESCE(dv.cantidad, 1), 0.0) AS ganancia_neta,
            $discountCol                                       AS line_discount
          FROM ventas v
          LEFT JOIN detalle_ventas dv ON v.id = dv.venta_id
          LEFT JOIN products p ON ($prodIdCol = p.id OR (p.sku = $prodIdCol AND $prodIdCol != ''))
          $whereClause
          ORDER BY $dateCol DESC
        ''', args);

        for (final row in rows) {
          final fecha = DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now();
          final totalVenta = (row['total_venta'] as num?)?.toDouble() ?? 0.0;
          final precioUnit = (row['precio_venta'] as num?)?.toDouble() ??
              (row['precio_unitario'] as num?)?.toDouble() ??
              totalVenta;
          final costoUnit = (row['precio_compra'] as num?)?.toDouble() ??
              (row['costo_unitario'] as num?)?.toDouble() ??
              0.0;

          entries.add(SalesHistoryEntry(
            ventaId: (row['venta_id'] ?? '').toString(),
            fecha: fecha,
            metodoPago: (row['metodo_pago'] as String?) ?? 'EFECTIVO',
            tipoEntrega: (row['tipo_entrega'] as String?) ?? 'MOSTRADOR',
            usuarioId: row['usuario_id'] as String?,
            clienteId: row['cliente_id'] as String?,
            clienteNombre: (row['cliente_nombre'] as String?) ?? 'Cliente Mostrador',
            detalleId: (row['detalle_id'] ?? '${row['venta_id']}_det').toString(),
            productId: (row['product_id'] ?? '').toString(),
            productName: (row['product_name'] ?? 'Venta General').toString(),
            sku: (row['sku'] as String?) ?? '-',
            cantidad: (row['cantidad'] as num?)?.toInt() ?? 1,
            costoUnitario: costoUnit,
            precioUnitario: precioUnit,
            lineDiscount: (row['line_discount'] as num?)?.toDouble() ?? 0.0,
          ));
        }

        if (entries.isNotEmpty) {
          return entries;
        }
      } catch (_) {}
    }

    return getSalesAuditHistory(date: null, usuarioId: usuarioId, origenVenta: origenVenta);
  }
}
