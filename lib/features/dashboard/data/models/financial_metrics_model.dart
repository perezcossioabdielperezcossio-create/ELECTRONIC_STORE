import 'package:equatable/equatable.dart';

class BalancePatrimonial extends Equatable {
  final double capitalInmovilizado;
  final double gananciaPotencial;

  const BalancePatrimonial({
    required this.capitalInmovilizado,
    required this.gananciaPotencial,
  });

  @override
  List<Object> get props => [capitalInmovilizado, gananciaPotencial];
}

class DesgloseMetodoPago extends Equatable {
  final String metodo;
  final double ingresoBruto;
  final double capitalBaseRecuperado;
  
  double get gananciaNetaReal => ingresoBruto - capitalBaseRecuperado;

  const DesgloseMetodoPago({
    required this.metodo,
    required this.ingresoBruto,
    required this.capitalBaseRecuperado,
  });

  @override
  List<Object> get props => [metodo, ingresoBruto, capitalBaseRecuperado];
}

class ArqueoDiario extends Equatable {
  final DateTime fecha;
  final double ingresoBrutoTotal;
  final double capitalBaseRecuperadoTotal;
  final List<DesgloseMetodoPago> desglose;

  double get gananciaNetaRealTotal => ingresoBrutoTotal - capitalBaseRecuperadoTotal;
  double get totalIngresos => ingresoBrutoTotal;

  double get ingresosEfectivo => _getIngresoPorMetodo('EFECTIVO');
  double get ingresosQr => _getIngresoPorMetodo('QR');
  double get ingresosTransferencia => _getIngresoPorMetodo('TRANSFERENCIA');
  double get ingresosTarjeta => _getIngresoPorMetodo('TARJETA');

  double _getIngresoPorMetodo(String method) {
    return desglose
        .where((d) => d.metodo.toUpperCase().trim() == method.toUpperCase().trim())
        .fold(0.0, (acc, d) => acc + d.ingresoBruto);
  }

  const ArqueoDiario({
    required this.fecha,
    required this.ingresoBrutoTotal,
    required this.capitalBaseRecuperadoTotal,
    required this.desglose,
  });

  @override
  List<Object> get props => [fecha, ingresoBrutoTotal, capitalBaseRecuperadoTotal, desglose];
}

class MetricaCanal extends Equatable {
  final String canal;
  final double totalIngresos;
  final double totalCostos;

  double get gananciaNeta => totalIngresos - totalCostos;
  double get margenNetoPorcentual => totalIngresos > 0 ? (gananciaNeta / totalIngresos) * 100 : 0.0;

  const MetricaCanal({
    required this.canal,
    required this.totalIngresos,
    required this.totalCostos,
  });

  @override
  List<Object> get props => [canal, totalIngresos, totalCostos];
}

class FinancialMetricsModel extends Equatable {
  final BalancePatrimonial balancePatrimonial;
  final ArqueoDiario arqueoDiario;
  final List<MetricaCanal> metricasCanal;

  const FinancialMetricsModel({
    required this.balancePatrimonial,
    required this.arqueoDiario,
    required this.metricasCanal,
  });

  @override
  List<Object> get props => [balancePatrimonial, arqueoDiario, metricasCanal];
}
