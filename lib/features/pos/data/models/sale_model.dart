import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';

class SaleModel extends Sale {
  const SaleModel({
    required super.id,
    required super.items,
    required super.createdAt,
    super.discount,
    super.tax,
    super.status,
    super.promoterId,
    super.notes,
    super.paymentMethod,
    super.deliveryMethod,
    super.deliveryFee,
    super.customerName,
    super.customerPhone,
  });

  factory SaleModel.fromMap(Map<String, dynamic> map,
      {List<SaleItem> items = const []}) =>
      SaleModel(
        id:         map['id'] as String,
        items:      items,
        createdAt:  DateTime.parse(map['created_at'] as String),
        discount:   (map['discount'] as num?)?.toDouble() ?? 0,
        tax:        (map['tax'] as num?)?.toDouble() ?? 0,
        status:     SaleStatus.values.byName(map['status'] as String),
        promoterId:     map['promoter_id'] as String?,
        notes:          map['notes'] as String?,
        paymentMethod:  map['payment_method'] as String? ?? 'EFECTIVO',
        deliveryMethod: map['delivery_method'] as String? ?? 'TIENDA',
        deliveryFee:    (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
        customerName:   map['customer_name'] as String?,
        customerPhone:  map['customer_phone'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'created_at':  createdAt.toIso8601String(),
        'discount':    discount,
        'tax':         tax,
        'status':      status.name,
        'promoter_id':       promoterId,
        'notes':             notes,
        'payment_method':    paymentMethod,
        'delivery_method':   deliveryMethod,
        'delivery_fee':      deliveryFee,
        'customer_name':     customerName,
        'customer_phone':    customerPhone,
        'total':             total,
      };
}
