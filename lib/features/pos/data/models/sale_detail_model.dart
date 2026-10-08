import '../../domain/entities/sale_detail.dart';

class SaleDetailModel extends SaleDetail {
  const SaleDetailModel({
    required super.id,
    required super.ventaId,
    super.loteId,
    required super.productId,
    required super.productName,
    required super.cantidad,
    required super.costoUnitarioCompra,
    required super.precioUnitarioCobrado,
    super.lineDiscount,
  });

  factory SaleDetailModel.fromMap(Map<String, dynamic> map) {
    return SaleDetailModel(
      id: (map['id'] as String?) ?? '',
      ventaId: (map['venta_id'] as String?) ?? (map['sale_id'] as String?) ?? '',
      loteId: (map['lote_id'] as String?) ?? (map['lot_id'] as String?),
      productId: (map['product_id'] as String?) ?? '',
      productName: (map['product_name'] as String?) ?? '',
      cantidad: (map['cantidad'] as num?)?.toInt() ?? (map['quantity'] as num?)?.toInt() ?? 1,
      costoUnitarioCompra: (map['costo_unitario_compra'] as num?)?.toDouble() ?? (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      precioUnitarioCobrado: (map['precio_unitario_cobrado'] as num?)?.toDouble() ?? (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      lineDiscount: (map['line_discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'venta_id': ventaId,
        'sale_id': ventaId,
        'lote_id': loteId,
        'lot_id': loteId,
        'product_id': productId,
        'product_name': productName,
        'cantidad': cantidad,
        'quantity': cantidad,
        'costo_unitario_compra': costoUnitarioCompra,
        'unit_cost': costoUnitarioCompra,
        'precio_unitario_cobrado': precioUnitarioCobrado,
        'unit_price': precioUnitarioCobrado,
        'line_discount': lineDiscount,
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'venta_id': ventaId,
        'lote_id': loteId,
        'product_id': productId,
        'product_name': productName,
        'cantidad': cantidad,
        'costo_unitario_compra': costoUnitarioCompra,
        'precio_unitario_cobrado': precioUnitarioCobrado,
        'line_discount': lineDiscount,
      };

  Map<String, dynamic> toSqliteSaleItemMap() => {
        'id': id,
        'sale_id': ventaId,
        'lote_id': loteId,
        'product_id': productId,
        'product_name': productName,
        'quantity': cantidad,
        'unit_price': precioUnitarioCobrado,
        'unit_cost': costoUnitarioCompra,
        'line_discount': lineDiscount,
      };
}
