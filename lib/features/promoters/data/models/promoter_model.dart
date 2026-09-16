import '../../domain/entities/promoter.dart';

class PromoterModel extends Promoter {
  const PromoterModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.commissionRate,
    super.email,
    super.isActive,
  });

  factory PromoterModel.fromMap(Map<String, dynamic> map) => PromoterModel(
        id:             map['id'] as String,
        name:           map['name'] as String,
        phone:          map['phone'] as String,
        email:          map['email'] as String?,
        commissionRate: (map['commission_rate'] as num).toDouble(),
        isActive:       (map['is_active'] as int) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'name':            name,
        'phone':           phone,
        'email':           email,
        'commission_rate': commissionRate,
        'is_active':       isActive ? 1 : 0,
      };
}
