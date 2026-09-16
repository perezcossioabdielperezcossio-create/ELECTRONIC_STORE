import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double sellingPrice;
  final String? imageUrl;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.sellingPrice,
    this.imageUrl,
    this.isActive = true,
  });

  @override
  List<Object?> get props =>
      [id, name, sku, category, sellingPrice, imageUrl, isActive];
}
