import 'package:equatable/equatable.dart';
import 'sale_item.dart';

enum SaleStatus { pending, completed, voided }

class Sale extends Equatable {
  final String id;
  final List<SaleItem> items;
  final double discount;
  final double tax;
  final DateTime createdAt;
  final SaleStatus status;
  final String? promoterId;
  final String? notes;
  final String paymentMethod;
  final String deliveryMethod;
  final double deliveryFee;
  final String? customerName;
  final String? customerPhone;

  const Sale({
    required this.id,
    required this.items,
    required this.createdAt,
    this.discount  = 0,
    this.tax       = 0,
    this.status    = SaleStatus.pending,
    this.promoterId,
    this.notes,
    this.paymentMethod = 'EFECTIVO',
    this.deliveryMethod = 'TIENDA',
    this.deliveryFee = 0.0,
    this.customerName,
    this.customerPhone,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.lineTotal);
  double get total    => subtotal - discount + tax;

  @override
  List<Object?> get props => [
        id, items, discount, tax, createdAt, status, promoterId, notes,
        paymentMethod, deliveryMethod, deliveryFee, customerName, customerPhone
      ];
}
