import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_detail.dart';
import 'sale_detail_model.dart';

class SaleModel extends Sale {
  const SaleModel({
    required super.id,
    super.clienteId,
    super.deliveryId,
    super.deliveryName,
    required super.items,
    super.details = const [],
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
    super.isLocked,
    super.storeLocation = 'ALMACEN',
    super.usuarioId,
  });

  factory SaleModel.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem> items = const [],
    List<SaleDetail> details = const [],
  }) {
    DateTime parsedDate;
    final rawDate = map['fecha_venta'] ?? map['created_at'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    SaleStatus parsedStatus = SaleStatus.completed;
    final rawStatus = map['status'] as String?;
    if (rawStatus != null) {
      final s = rawStatus.toLowerCase().trim();
      if (s == 'voided' || s == 'anulada') {
        parsedStatus = SaleStatus.voided;
      } else {
        parsedStatus = SaleStatus.completed;
      }
    }

    // Parse details if present in the map
    List<SaleDetail> parsedDetails = List.from(details);
    if (parsedDetails.isEmpty && map['sale_details'] is List) {
      parsedDetails = (map['sale_details'] as List)
          .map((d) => SaleDetailModel.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList();
    }

    // Parse items if empty and details are available or items list is in the map
    List<SaleItem> parsedItems = List.from(items);
    if (parsedItems.isEmpty && map['items'] is List) {
      parsedItems = (map['items'] as List).map((i) {
        final m = Map<String, dynamic>.from(i as Map);
        return SaleItem(
          productId: (m['product_id'] as String?) ?? '',
          productName: (m['product_name'] as String?) ?? '',
          quantity: (m['quantity'] as num?)?.toInt() ?? (m['cantidad'] as num?)?.toInt() ?? 1,
          unitPrice: (m['unit_price'] as num?)?.toDouble() ?? (m['precio_unitario_cobrado'] as num?)?.toDouble() ?? 0.0,
          unitCost: (m['unit_cost'] as num?)?.toDouble() ?? (m['costo_unitario_compra'] as num?)?.toDouble() ?? 0.0,
          lineDiscount: (m['line_discount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } else if (parsedItems.isEmpty && parsedDetails.isNotEmpty) {
      parsedItems = parsedDetails.map((d) => SaleItem(
        productId: d.productId,
        productName: d.productName,
        quantity: d.cantidad,
        unitPrice: d.precioUnitarioCobrado,
        unitCost: d.costoUnitarioCompra,
        lineDiscount: d.lineDiscount,
      )).toList();
    }

    final rawLocation = (map['origen_venta'] ?? map['origenVenta'] ?? map['store_location'] ?? map['storeLocation'] ?? map['location'] ?? map['ubicacion'] ?? 'ALMACEN').toString().toUpperCase().trim();
    final parsedLocation = rawLocation == 'TIENDA' ? 'TIENDA' : 'ALMACEN';

    return SaleModel(
      id: (map['id'] as String?) ?? '',
      clienteId: (map['cliente_id'] as String?),
      deliveryId: (map['delivery_id'] as String?) ?? (map['repartidor_id'] as String?),
      deliveryName: (map['delivery_name'] as String?) ?? (map['repartidor_nombre'] as String?),
      items: parsedItems,
      details: parsedDetails,
      createdAt: parsedDate,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0,
      status: parsedStatus,
      promoterId: map['promoter_id'] as String?,
      notes: map['notes'] as String?,
      paymentMethod: (map['metodo_pago'] as String?) ?? (map['payment_method'] as String?) ?? 'EFECTIVO',
      deliveryMethod: (map['tipo_entrega'] as String?) ?? (map['delivery_method'] as String?) ?? 'TIENDA',
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      customerName: (map['customer_name'] as String?) ?? (map['nombre_alias'] as String?),
      customerPhone: (map['customer_phone'] as String?) ?? (map['telefono_whatsapp'] as String?),
      isLocked: map['is_locked'] == 1 || map['is_locked'] == true,
      storeLocation: parsedLocation,
      usuarioId: (map['usuario_id'] ?? map['usuarioId'] ?? map['user_id']) as String?,
    );
  }

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      clienteId: sale.clienteId,
      deliveryId: sale.deliveryId,
      deliveryName: sale.deliveryName,
      items: sale.items,
      details: sale.details,
      createdAt: sale.createdAt,
      discount: sale.discount,
      tax: sale.tax,
      status: sale.status,
      promoterId: sale.promoterId,
      notes: sale.notes,
      paymentMethod: sale.paymentMethod,
      deliveryMethod: sale.deliveryMethod,
      deliveryFee: sale.deliveryFee,
      customerName: sale.customerName,
      customerPhone: sale.customerPhone,
      isLocked: sale.isLocked,
      storeLocation: sale.storeLocation,
      usuarioId: sale.usuarioId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'delivery_id': deliveryId,
        'delivery_name': deliveryName,
        'repartidor_id': deliveryId,
        'repartidor_nombre': deliveryName,
        'total_cobrado': total,
        'metodo_pago': paymentMethod,
        'tipo_entrega': deliveryMethod,
        'fecha_venta': createdAt.toIso8601String(),
        'is_locked': isLocked,
        'created_at': createdAt.toIso8601String(),
        'payment_method': paymentMethod,
        'delivery_method': deliveryMethod,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'tax': tax,
        'status': status == SaleStatus.voided ? 'VOIDED' : 'COMPLETED',
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'promoter_id': promoterId,
        'notes': notes,
        'total': total,
        'store_location': storeLocation,
        'location': storeLocation,
        'origen_venta': storeLocation,
        'usuario_id': usuarioId,
        'sale_details': details.isNotEmpty
            ? details.map((d) {
                if (d is SaleDetailModel) return d.toMap();
                return SaleDetailModel(
                  id: d.id,
                  ventaId: d.ventaId,
                  loteId: d.loteId,
                  productId: d.productId,
                  productName: d.productName,
                  cantidad: d.cantidad,
                  costoUnitarioCompra: d.costoUnitarioCompra,
                  precioUnitarioCobrado: d.precioUnitarioCobrado,
                  lineDiscount: d.lineDiscount,
                ).toMap();
              }).toList()
            : items.map((i) => {
                'id': '${id}_${i.productId}',
                'venta_id': id,
                'sale_id': id,
                'product_id': i.productId,
                'product_name': i.productName,
                'cantidad': i.quantity,
                'quantity': i.quantity,
                'costo_unitario_compra': i.unitCost,
                'unit_cost': i.unitCost,
                'precio_unitario_cobrado': i.unitPrice,
                'unit_price': i.unitPrice,
                'line_discount': i.lineDiscount,
              }).toList(),
        'items': items.map((i) => {
          'id': '${id}_${i.productId}',
          'sale_id': id,
          'product_id': i.productId,
          'product_name': i.productName,
          'quantity': i.quantity,
          'unit_price': i.unitPrice,
          'unit_cost': i.unitCost,
          'line_discount': i.lineDiscount,
        }).toList(),
      };

  Map<String, dynamic> toSqliteVentasMap() => {
        'id': id,
        'cliente_id': clienteId,
        'delivery_id': deliveryId,
        'delivery_name': deliveryName,
        'total_cobrado': total,
        'metodo_pago': paymentMethod,
        'tipo_entrega': deliveryMethod,
        'fecha_venta': createdAt.toIso8601String(),
        'is_locked': 1,
        'created_at': createdAt.toIso8601String(),
        'payment_method': paymentMethod,
        'delivery_method': deliveryMethod,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'tax': tax,
        'total': total,
        'status': status == SaleStatus.voided ? 'VOIDED' : 'COMPLETED',
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'promoter_id': promoterId,
        'notes': notes,
        'store_location': storeLocation,
        'origen_venta': storeLocation,
        'usuario_id': usuarioId,
      };

  Map<String, dynamic> toSqliteSalesMap() => {
        'id': id,
        'cliente_id': clienteId,
        'delivery_id': deliveryId,
        'delivery_name': deliveryName,
        'total_cobrado': total,
        'metodo_pago': paymentMethod,
        'tipo_entrega': deliveryMethod,
        'fecha_venta': createdAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'payment_method': paymentMethod,
        'delivery_method': deliveryMethod,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'tax': tax,
        'total': total,
        'status': status == SaleStatus.voided ? 'VOIDED' : 'COMPLETED',
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'promoter_id': promoterId,
        'notes': notes,
        'is_locked': 1,
        'store_location': storeLocation,
        'origen_venta': storeLocation,
        'usuario_id': usuarioId,
      };
}
