import 'package:equatable/equatable.dart';

enum UserRole {
  admin,
  seller;

  static UserRole fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'admin':
        return UserRole.admin;
      case 'seller':
      default:
        return UserRole.seller;
    }
  }

  String get value => name;
}

class User extends Equatable {
  final String celular;
  final String nombre;
  final String pin;
  final UserRole role;
  final String tiendaNombre;
  final bool activo;

  const User({
    required this.celular,
    required this.nombre,
    required this.pin,
    required this.role,
    required this.tiendaNombre,
    this.activo = true,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSeller => role == UserRole.seller;

  // Master Admins definition
  static const String admin1Phone = '67606367';
  static const String admin1Pin = '696910';
  static const String admin1Name = 'Abdiel Perez Cossio';
  static const String admin1Store = 'Almacén Central';

  static const String admin2Phone = '77111575';
  static const String admin2Pin = '000000';
  static const String admin2Name = 'Arianna Duran Nava';
  static const String admin2Store = 'Almacén Central';

  static const List<String> masterAdminPins = [admin1Pin, admin2Pin];

  static bool isValidAdminPin(String pin) {
    return masterAdminPins.contains(pin.trim());
  }

  @override
  List<Object?> get props => [celular, nombre, pin, role, tiendaNombre, activo];
}
