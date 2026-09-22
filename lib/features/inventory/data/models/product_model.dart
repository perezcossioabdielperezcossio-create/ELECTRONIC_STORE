import '../../domain/entities/product.dart';
import '../../domain/entities/lot.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.sku,
    required super.name,
    required super.brand,
    required super.category,
    required super.standardSellingPrice,
    required super.minStockThreshold,
    super.lots,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, {List<Lot>? lots}) {
    return ProductModel(
      id: map['id'] as String,
      sku: map['sku'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      standardSellingPrice: (map['standard_selling_price'] as num).toDouble(),
      minStockThreshold: map['min_stock_threshold'] as int,
      lots: lots ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'brand': brand,
      'category': category,
      'standard_selling_price': standardSellingPrice,
      'min_stock_threshold': minStockThreshold,
    };
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      sku: product.sku,
      name: product.name,
      brand: product.brand,
      category: product.category,
      standardSellingPrice: product.standardSellingPrice,
      minStockThreshold: product.minStockThreshold,
      lots: product.lots,
    );
  }
}
