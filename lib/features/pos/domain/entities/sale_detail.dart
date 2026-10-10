import 'package:equatable/equatable.dart';

class SaleDetail extends Equatable {
  final String id;
  final String ventaId;
  final String? loteId;
  final String productId;
  final String productName;
  final int cantidad;
  final double costoUnitarioCompra;
  final double precioUnitarioCobrado;
  final double lineDiscount;

  const SaleDetail({
    required this.id,
    required this.ventaId,
    this.loteId,
    required this.productId,
    required this.productName,
    required this.cantidad,
    required this.costoUnitarioCompra,
    required this.precioUnitarioCobrado,
    this.lineDiscount = 0.0,
  });

  // Aliases for compatibility
  String get saleId => ventaId;
  String? get lotId => loteId;
  int get quantity => cantidad;
  double get unitCost => costoUnitarioCompra;
  double get unitPrice => precioUnitarioCobrado;
  double get lineTotal => (precioUnitarioCobrado * cantidad) - lineDiscount;
  double get totalCost => costoUnitarioCompra * cantidad;
  double get profit => lineTotal - totalCost;

  @override
  List<Object?> get props => [
        id,
        ventaId,
        loteId,
        productId,
        productName,
        cantidad,
        costoUnitarioCompra,
        precioUnitarioCobrado,
        lineDiscount,
      ];
}
