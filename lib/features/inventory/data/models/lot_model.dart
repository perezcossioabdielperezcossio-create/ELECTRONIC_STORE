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
  });

  factory LotModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? map['lot_id'] ?? '') as String;
    final productId = (map['product_id'] ?? map['productId'] ?? map['productSku'] ?? '') as String;
    
    DateTime purchaseDate;
    final dateVal = map['purchase_date'] ?? map['purchaseDate'] ?? map['fecha_ingreso'] ?? map['fechaIngreso'];
    if (dateVal is String) {
      purchaseDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      purchaseDate = DateTime.now();
    }

    final currentQty = ((map['current_quantity'] ?? map['currentQuantity'] ?? map['cantidad_actual'] ?? map['cantidadActual'] ?? 0) as num).toInt();
    final initialQty = ((map['initial_quantity'] ?? map['initialQuantity'] ?? map['cantidad_inicial'] ?? map['cantidadInicial'] ?? currentQty) as num).toInt();
    final realCost = ((map['real_unit_cost'] ?? map['realUnitCost'] ?? map['costo_unitario_real'] ?? map['costoUnitarioReal'] ?? 0.0) as num).toDouble();
    
    final basePriceVal = map['promoter_base_price'] ?? map['promoterBasePrice'] ?? map['precio_base_promotor'];
    final promoterBasePrice = basePriceVal != null ? (basePriceVal as num).toDouble() : null;

    return LotModel(
      id: id,
      productId: productId,
      purchaseDate: purchaseDate,
      initialQuantity: initialQty < currentQty ? currentQty : initialQty,
      currentQuantity: currentQty,
      realUnitCost: realCost,
      promoterBasePrice: promoterBasePrice,
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
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toMap() {
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
      'real_unit_cost': realUnitCost,
      'costo_unitario_real': realUnitCost,
      'promoter_base_price': promoterBasePrice,
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
    );
  }
}
