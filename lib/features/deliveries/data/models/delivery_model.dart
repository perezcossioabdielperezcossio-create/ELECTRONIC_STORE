import '../../domain/entities/delivery.dart';

class DeliveryModel extends Delivery {
  const DeliveryModel({
    required super.id,
    required super.nombre,
    required super.telefono,
    super.vehiculo,
    super.activo,
    required super.creadoEn,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['creado_en'] ?? map['created_at'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final dynamic rawActivo = map['activo'] ?? map['is_active'] ?? map['active'];
    final bool isActivo = rawActivo == 1 || rawActivo == true || rawActivo == '1' || rawActivo == null;

    return DeliveryModel(
      id: (map['id'] as String?) ?? '',
      nombre: (map['nombre'] as String?) ?? (map['name'] as String?) ?? '',
      telefono: (map['telefono'] as String?) ?? (map['phone'] as String?) ?? '',
      vehiculo: (map['vehiculo'] as String?) ?? (map['vehicle'] as String?),
      activo: isActivo,
      creadoEn: parsedDate,
    );
  }

  factory DeliveryModel.fromEntity(Delivery delivery) {
    return DeliveryModel(
      id: delivery.id,
      nombre: delivery.nombre,
      telefono: delivery.telefono,
      vehiculo: delivery.vehiculo,
      activo: delivery.activo,
      creadoEn: delivery.creadoEn,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'vehiculo': vehiculo,
        'activo': activo ? 1 : 0,
        'creado_en': creadoEn.toIso8601String(),
        'name': nombre,
        'phone': telefono,
        'vehicle': vehiculo,
        'is_active': activo ? 1 : 0,
        'created_at': creadoEn.toIso8601String(),
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'vehiculo': vehiculo,
        'activo': activo ? 1 : 0,
        'creado_en': creadoEn.toIso8601String(),
      };
}
