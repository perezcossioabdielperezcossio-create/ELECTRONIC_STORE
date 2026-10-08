import 'package:flutter_test/flutter_test.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel & Master Admins', () {
    test('Master Admin 1 has correct credentials and role', () {
      final admin1 = UserModel.masterAdmin1;
      expect(admin1.nombre, 'Abdiel Perez Cossio');
      expect(admin1.celular, '67606367');
      expect(admin1.pin, '696910');
      expect(admin1.role, UserRole.admin);
      expect(admin1.tiendaNombre, 'Almacén Central');
      expect(admin1.activo, true);
      expect(admin1.isAdmin, true);
      expect(admin1.isSeller, false);
    });

    test('Master Admin 2 has correct credentials and role', () {
      final admin2 = UserModel.masterAdmin2;
      expect(admin2.nombre, 'Arianna Duran Nava');
      expect(admin2.celular, '77111575');
      expect(admin2.pin, '000000');
      expect(admin2.role, UserRole.admin);
      expect(admin2.tiendaNombre, 'Almacén Central');
      expect(admin2.activo, true);
      expect(admin2.isAdmin, true);
      expect(admin2.isSeller, false);
    });

    test('User.isValidAdminPin validates correctly', () {
      expect(User.isValidAdminPin('696910'), true);
      expect(User.isValidAdminPin('000000'), true);
      expect(User.isValidAdminPin('123456'), false);
      expect(User.isValidAdminPin(''), false);
    });

    test('toMap and fromMap serialize and deserialize accurately', () {
      const seller = UserModel(
        celular: '70012345',
        nombre: 'Carlos Perez',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal Norte',
        activo: true,
      );

      final map = seller.toMap();
      expect(map['celular'], '70012345');
      expect(map['nombre'], 'Carlos Perez');
      expect(map['pin'], '123456');
      expect(map['role'], 'seller');
      expect(map['tienda_nombre'], 'Sucursal Norte');
      expect(map['activo'], 1);

      final fromMap = UserModel.fromMap(map);
      expect(fromMap, seller);
    });

    test('toFirestore and fromJson serialize and deserialize accurately', () {
      const seller = UserModel(
        celular: '70012345',
        nombre: 'Carlos Perez',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal Norte',
        activo: true,
      );

      final firestoreMap = seller.toFirestore();
      expect(firestoreMap['celular'], '70012345');
      expect(firestoreMap['nombre'], 'Carlos Perez');
      expect(firestoreMap['role'], 'seller');
      expect(firestoreMap['tienda_nombre'], 'Sucursal Norte');
      expect(firestoreMap['activo'], true);

      final fromJson = UserModel.fromJson({
        'celular': '70012345',
        'nombre': 'Carlos Perez',
        'pin': '123456',
        'role': 'seller',
        'tienda_nombre': 'Sucursal Norte',
        'activo': true,
      });
      expect(fromJson, seller);
    });
  });
}
