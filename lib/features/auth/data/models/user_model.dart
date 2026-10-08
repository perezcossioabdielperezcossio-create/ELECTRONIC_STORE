import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.celular,
    required super.nombre,
    required super.pin,
    required super.role,
    required super.tiendaNombre,
    super.activo = true,
  });

  static const UserModel masterAdmin1 = UserModel(
    celular: User.admin1Phone,
    nombre: User.admin1Name,
    pin: User.admin1Pin,
    role: UserRole.admin,
    tiendaNombre: User.admin1Store,
    activo: true,
  );

  static const UserModel masterAdmin2 = UserModel(
    celular: User.admin2Phone,
    nombre: User.admin2Name,
    pin: User.admin2Pin,
    role: UserRole.admin,
    tiendaNombre: User.admin2Store,
    activo: true,
  );

  static const List<UserModel> masterAdmins = [masterAdmin1, masterAdmin2];

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawActivo = map['activo'] ?? map['is_active'];
    final bool activoVal;
    if (rawActivo is bool) {
      activoVal = rawActivo;
    } else if (rawActivo is num) {
      activoVal = rawActivo == 1;
    } else {
      activoVal = true;
    }

    return UserModel(
      celular: (map['celular'] ?? map['phone'] ?? '').toString(),
      nombre: (map['nombre'] ?? map['name'] ?? '').toString(),
      pin: (map['pin'] ?? '').toString(),
      role: UserRole.fromString((map['role'] ?? 'seller').toString()),
      tiendaNombre: (map['tienda_nombre'] ?? map['tiendaNombre'] ?? map['store_name'] ?? '').toString(),
      activo: activoVal,
    );
  }

  Map<String, dynamic> toMap() => {
    'celular': celular,
    'nombre': nombre,
    'pin': pin,
    'role': role.value,
    'tienda_nombre': tiendaNombre,
    'activo': activo ? 1 : 0,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromMap(json);

  Map<String, dynamic> toJson() => {
    'celular': celular,
    'nombre': nombre,
    'pin': pin,
    'role': role.value,
    'tiendaNombre': tiendaNombre,
    'activo': activo,
  };

  Map<String, dynamic> toFirestore() => {
    'celular': celular,
    'nombre': nombre,
    'pin': pin,
    'role': role.value,
    'tienda_nombre': tiendaNombre,
    'activo': activo,
  };

  UserModel copyWith({
    String? celular,
    String? nombre,
    String? pin,
    UserRole? role,
    String? tiendaNombre,
    bool? activo,
  }) {
    return UserModel(
      celular: celular ?? this.celular,
      nombre: nombre ?? this.nombre,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      tiendaNombre: tiendaNombre ?? this.tiendaNombre,
      activo: activo ?? this.activo,
    );
  }
}
