import 'package:equatable/equatable.dart';

class Delivery extends Equatable {
  final String id;
  final String nombre;
  final String telefono;
  final String? vehiculo;
  final bool activo;
  final DateTime creadoEn;

  const Delivery({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.vehiculo,
    this.activo = true,
    required this.creadoEn,
  });

  // Aliases for clean compatibility
  String get name => nombre;
  String get phone => telefono;
  String? get vehicle => vehiculo;
  bool get isActive => activo;
  DateTime get createdAt => creadoEn;

  Delivery copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? vehiculo,
    bool? activo,
    DateTime? creadoEn,
  }) {
    return Delivery(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      vehiculo: vehiculo ?? this.vehiculo,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props => [id, nombre, telefono, vehiculo, activo, creadoEn];
}
