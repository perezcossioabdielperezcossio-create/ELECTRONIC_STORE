import '../../domain/entities/lot.dart';

class LotModel extends Lot {
  const LotModel({
    required super.id,
    required super.productId,
    required super.purchaseDate,
    required super.initialQuantity,
    required super.currentQuantity,
    required super.realUnitCost,
    super.promoterBasePrice,
    super.location = 'ALMACEN',
  });

  factory LotModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? map['lot_id'] ?? '') as String;
    final productId = (map['product_id'] ?? map['productId'] ?? map['productSku'] ?? '') as String;
    
    DateTime purchaseDate;
    final dateVal = map['purchase_date'] ?? map['purchaseDate'] ?? map['fecha_ingreso'] ?? map['fechaIngreso'] ?? map['updated_at'];
    if (dateVal is String) {
      purchaseDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      purchaseDate = DateTime.now();
    }

    final currentQty = ((map['current_quantity'] ?? map['currentQuantity'] ?? map['cantidad_actual'] ?? map['cantidadActual'] ?? map['current_qty'] ?? 0) as num).toInt();
    final initialQty = ((map['initial_quantity'] ?? map['initialQuantity'] ?? map['cantidad_inicial'] ?? map['cantidadInicial'] ?? map['initial_qty'] ?? currentQty) as num).toInt();
    final realCost = ((map['real_unit_cost'] ?? map['realUnitCost'] ?? map['costo_unitario_real'] ?? map['costoUnitarioReal'] ?? map['unit_cost'] ?? 0.0) as num).toDouble();
    
    final basePriceVal = map['promoter_base_price'] ?? map['promoterBasePrice'] ?? map['precio_base_promotor'] ?? map['unit_price'] ?? map['precio_unitario'];
    final promoterBasePrice = basePriceVal != null ? (basePriceVal as num).toDouble() : null;

    final locationRaw = (map['location'] ?? map['ubicacion'] ?? 'ALMACEN').toString().toUpperCase().trim();
    final location = locationRaw.contains('TIENDA') ? 'TIENDA' : 'ALMACEN';

    return LotModel(
      id: id,
      productId: productId,
      purchaseDate: purchaseDate,
      initialQuantity: initialQty < currentQty ? currentQty : initialQty,
      currentQuantity: currentQty,
      realUnitCost: realCost,
      promoterBasePrice: promoterBasePrice,
      location: location,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'product_id': productId,
      'purchase_date': purchaseDate.toIso8601String(),
      'initial_quantity': initialQuantity,
      'current_quantity': currentQuantity,
      'real_unit_cost': realUnitCost,
      'promoter_base_price': promoterBasePrice,
      'location': location,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() {
    final nowIso = DateTime.now().toIso8601String();
    return {
      'id': id,
      'product_id': productId,
      'productSku': productId,
      'productId': productId,
      'purchase_date': purchaseDate.toIso8601String(),
      'fecha_ingreso': purchaseDate.toIso8601String(),
      'initial_quantity': initialQuantity,
      'cantidad_inicial': initialQuantity,
      'current_quantity': currentQuantity,
      'cantidad_actual': currentQuantity,
      'current_qty': currentQuantity,
      'real_unit_cost': realUnitCost,
      'costo_unitario_real': realUnitCost,
      'unit_cost': realUnitCost,
      'promoter_base_price': promoterBasePrice,
      'unit_price': promoterBasePrice,
      'location': location,
      'ubicacion': location,
      'updated_at': nowIso,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory LotModel.fromEntity(Lot lot) {
    return LotModel(
      id: lot.id,
      productId: lot.productId,
      purchaseDate: lot.purchaseDate,
      initialQuantity: lot.initialQuantity,
      currentQuantity: lot.currentQuantity,
      realUnitCost: lot.realUnitCost,
      promoterBasePrice: lot.promoterBasePrice,
      location: lot.location,
    );
  }
}
