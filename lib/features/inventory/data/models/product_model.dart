import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.sku,
    required super.category,
    required super.sellingPrice,
    super.imageUrl,
    super.isActive,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
        id:           map['id'] as String,
        name:         map['name'] as String,
        sku:          map['sku'] as String,
        category:     map['category'] as String,
        sellingPrice: (map['selling_price'] as num).toDouble(),
        imageUrl:     map['image_url'] as String?,
        isActive:     (map['is_active'] as int) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id':            id,
        'name':          name,
        'sku':           sku,
        'category':      category,
        'selling_price': sellingPrice,
        'image_url':     imageUrl,
        'is_active':     isActive ? 1 : 0,
      };

  factory ProductModel.fromEntity(Product p) => ProductModel(
        id:           p.id,
        name:         p.name,
        sku:          p.sku,
        category:     p.category,
        sellingPrice: p.sellingPrice,
        imageUrl:     p.imageUrl,
        isActive:     p.isActive,
      );
}
