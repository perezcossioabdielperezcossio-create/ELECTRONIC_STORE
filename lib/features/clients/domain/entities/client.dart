import 'package:equatable/equatable.dart';

class Client extends Equatable {
  final String id;
  final String nombreAlias;
  final String? telefonoWhatsapp;
  final String? direccionPredet;
  final DateTime creadoEn;

  const Client({
    required this.id,
    required this.nombreAlias,
    this.telefonoWhatsapp,
    this.direccionPredet,
    required this.creadoEn,
  });

  // Helper getters for compatibility
  String get name => nombreAlias;
  String? get phone => telefonoWhatsapp;
  String? get address => direccionPredet;
  DateTime get createdAt => creadoEn;

  Client copyWith({
    String? id,
    String? nombreAlias,
    String? telefonoWhatsapp,
    String? direccionPredet,
    DateTime? creadoEn,
  }) {
    return Client(
      id: id ?? this.id,
      nombreAlias: nombreAlias ?? this.nombreAlias,
      telefonoWhatsapp: telefonoWhatsapp ?? this.telefonoWhatsapp,
      direccionPredet: direccionPredet ?? this.direccionPredet,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props => [id, nombreAlias, telefonoWhatsapp, direccionPredet, creadoEn];
}
