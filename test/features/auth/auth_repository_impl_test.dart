import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:electronic_store/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:electronic_store/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockAuthLocalDataSource mockLocalDs;
  late MockAuthRemoteDataSource mockRemoteDs;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(UserModel.masterAdmin1);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockLocalDs = MockAuthLocalDataSource();
    mockRemoteDs = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(
      localDataSource: mockLocalDs,
      remoteDataSource: mockRemoteDs,
    );
  });

  group('AuthRepositoryImpl - Login', () {
    test('successful login with master admin 1', () async {
      when(() => mockLocalDs.getUserByPhone('67606367'))
          .thenAnswer((_) async => UserModel.masterAdmin1);

      final result = await repository.login(celular: '67606367', pin: '696910');

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should succeed'),
        (user) {
          expect(user.nombre, 'Abdiel Perez Cossio');
          expect(user.isAdmin, true);
        },
      );
    });

    test('login fails when PIN is incorrect', () async {
      when(() => mockLocalDs.getUserByPhone('67606367'))
          .thenAnswer((_) async => UserModel.masterAdmin1);

      final result = await repository.login(celular: '67606367', pin: 'wrongPin');

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message.contains('PIN incorrecto'), true),
        (user) => fail('Should fail'),
      );
    });

    test('login falls back to remote if user not found locally and caches it', () async {
      when(() => mockLocalDs.getUserByPhone('77111575'))
          .thenAnswer((_) async => null);
      when(() => mockRemoteDs.getUserByPhoneRemote('77111575'))
          .thenAnswer((_) async => UserModel.masterAdmin2);
      when(() => mockLocalDs.saveUser(any()))
          .thenAnswer((_) async {});

      final result = await repository.login(celular: '77111575', pin: '000000');

      expect(result.isRight(), true);
      verify(() => mockLocalDs.saveUser(UserModel.masterAdmin2)).called(1);
    });
  });

  group('AuthRepositoryImpl - Register Seller', () {
    const newSeller = UserModel(
      celular: '71234567',
      nombre: 'Pedro Ramirez',
      pin: '112233',
      role: UserRole.seller,
      tiendaNombre: 'Tienda Central',
      activo: true,
    );

    test('successfully registers seller when valid admin PIN is provided (Abdiel 696910)', () async {
      when(() => mockLocalDs.getUserByPhone('71234567')).thenAnswer((_) async => null);
      when(() => mockLocalDs.saveUser(any())).thenAnswer((_) async {});
      when(() => mockRemoteDs.saveUserRemote(any())).thenAnswer((_) async {});

      final result = await repository.registerSeller(
        user: newSeller,
        adminPin: '696910',
      );

      expect(result.isRight(), true);
      verify(() => mockLocalDs.saveUser(any())).called(1);
      verify(() => mockRemoteDs.saveUserRemote(any())).called(1);
    });

    test('successfully registers seller when valid admin PIN is provided (Arianna 000000)', () async {
      when(() => mockLocalDs.getUserByPhone('71234567')).thenAnswer((_) async => null);
      when(() => mockLocalDs.saveUser(any())).thenAnswer((_) async {});
      when(() => mockRemoteDs.saveUserRemote(any())).thenAnswer((_) async {});

      final result = await repository.registerSeller(
        user: newSeller,
        adminPin: '000000',
      );

      expect(result.isRight(), true);
    });

    test('rejects registration when admin PIN is invalid', () async {
      final result = await repository.registerSeller(
        user: newSeller,
        adminPin: '999999',
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, 'PIN de Administrador inválido. Registro rechazado'),
        (_) => fail('Should reject'),
      );
    });

    test('strictly forbids registering with admin role', () async {
      const adminAttempt = UserModel(
        celular: '79999999',
        nombre: 'Fake Admin',
        pin: '123456',
        role: UserRole.admin,
        tiendaNombre: 'Fake',
      );

      final result = await repository.registerSeller(
        user: adminAttempt,
        adminPin: '696910',
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message.contains('prohibido'), true),
        (_) => fail('Should reject admin registration'),
      );
    });
  });

  group('AuthRepositoryImpl - Session management', () {
    test('saveSession, getSavedSession and clearSession work with SharedPreferences', () async {
      await repository.saveSession(UserModel.masterAdmin1);

      final session = await repository.getSavedSession();
      expect(session, isNotNull);
      expect(session!.celular, '67606367');
      expect(session.nombre, 'Abdiel Perez Cossio');
      expect(session.role, UserRole.admin);

      await repository.clearSession();
      final clearedSession = await repository.getSavedSession();
      expect(clearedSession, isNull);
    });
  });
}
