import 'package:equatable/equatable.dart';
import 'sale_item.dart';
import 'sale_detail.dart';

enum SaleStatus { pending, completed, voided }

class Sale extends Equatable {
  final String id;
  final String? clienteId;
  final String? deliveryId;
  final String? deliveryName;
  final List<SaleItem> items;
  final List<SaleDetail> details;
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
  final bool isLocked;
  final String storeLocation; // 'TIENDA' or 'ALMACEN'
  final String? usuarioId; // Celular del usuario que procesó la venta

  const Sale({
    required this.id,
    this.clienteId,
    this.deliveryId,
    this.deliveryName,
    required this.items,
    this.details = const [],
    required this.createdAt,
    this.discount = 0,
    this.tax = 0,
    this.status = SaleStatus.completed,
    this.promoterId,
    this.notes,
    this.paymentMethod = 'EFECTIVO',
    this.deliveryMethod = 'TIENDA',
    this.deliveryFee = 0.0,
    this.customerName,
    this.customerPhone,
    this.isLocked = true,
    this.storeLocation = 'ALMACEN',
    this.usuarioId,
  });

  // Aliases for clean CRM / Ventas naming
  DateTime get fechaVenta => createdAt;
  DateTime get date => createdAt;
  String get metodoPago => paymentMethod;
  String get tipoEntrega => deliveryMethod;
  double get totalCobrado => total;
  double get totalAmount => total;
  String? get clientName => customerName;
  String? get repartidorId => deliveryId;
  String? get repartidorNombre => deliveryName;
  String get ubicacionOrigen => storeLocation;
  String get origenVenta => storeLocation;
  String? get userId => usuarioId;

  double get subtotal => items.isNotEmpty
      ? items.fold(0, (s, i) => s + i.lineTotal)
      : details.fold(0, (s, d) => s + d.lineTotal);

  double get total => (subtotal - discount + tax + deliveryFee) > 0 ? (subtotal - discount + tax + deliveryFee) : 0.0;

  double get totalCost => details.isNotEmpty
      ? details.fold(0.0, (s, d) => s + d.totalCost)
      : items.fold(0.0, (s, i) => s + (i.unitCost * i.quantity));

  double get netProfit => total - totalCost;

  Sale copyWith({
    String? id,
    String? clienteId,
    String? deliveryId,
    String? deliveryName,
    List<SaleItem>? items,
    List<SaleDetail>? details,
    DateTime? createdAt,
    double? discount,
    double? tax,
    SaleStatus? status,
    String? promoterId,
    String? notes,
    String? paymentMethod,
    String? deliveryMethod,
    double? deliveryFee,
    String? customerName,
    String? customerPhone,
    bool? isLocked,
    String? storeLocation,
    String? usuarioId,
    String? origenVenta,
  }) {
    return Sale(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryName: deliveryName ?? this.deliveryName,
      items: items ?? this.items,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      status: status ?? this.status,
      promoterId: promoterId ?? this.promoterId,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isLocked: isLocked ?? this.isLocked,
      storeLocation: origenVenta ?? storeLocation ?? this.storeLocation,
      usuarioId: usuarioId ?? this.usuarioId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        clienteId,
        deliveryId,
        deliveryName,
        items,
        details,
        discount,
        tax,
        createdAt,
        status,
        promoterId,
        notes,
        paymentMethod,
        deliveryMethod,
        deliveryFee,
        customerName,
        customerPhone,
        isLocked,
        storeLocation,
        usuarioId,
      ];
}
