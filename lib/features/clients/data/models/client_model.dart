import '../../domain/entities/client.dart';

class ClientModel extends Client {
  const ClientModel({
    required super.id,
    required super.nombreAlias,
    super.telefonoWhatsapp,
    super.direccionPredet,
    required super.creadoEn,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['creado_en'] ?? map['created_at'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ClientModel(
      id: (map['id'] as String?) ?? '',
      nombreAlias: (map['nombre_alias'] as String?) ?? (map['name'] as String?) ?? '',
      telefonoWhatsapp: (map['telefono_whatsapp'] as String?) ?? (map['phone'] as String?),
      direccionPredet: (map['direccion_predet'] as String?) ?? (map['address'] as String?) ?? (map['email'] as String?),
      creadoEn: parsedDate,
    );
  }

  factory ClientModel.fromEntity(Client client) {
    return ClientModel(
      id: client.id,
      nombreAlias: client.nombreAlias,
      telefonoWhatsapp: client.telefonoWhatsapp,
      direccionPredet: client.direccionPredet,
      creadoEn: client.creadoEn,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre_alias': nombreAlias,
        'telefono_whatsapp': telefonoWhatsapp,
        'direccion_predet': direccionPredet,
        'creado_en': creadoEn.toIso8601String(),
        'name': nombreAlias,
        'phone': telefonoWhatsapp,
        'address': direccionPredet,
        'created_at': creadoEn.toIso8601String(),
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'nombre_alias': nombreAlias,
        'telefono_whatsapp': telefonoWhatsapp ?? '',
        'direccion_predet': direccionPredet,
        'creado_en': creadoEn.toIso8601String(),
      };

  Map<String, dynamic> toSqliteCustomerMap() => {
        'id': id,
        'name': nombreAlias,
        'phone': telefonoWhatsapp ?? '',
        'email': direccionPredet,
        'created_at': creadoEn.toIso8601String(),
      };
}
