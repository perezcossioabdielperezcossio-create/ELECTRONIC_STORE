import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource localDataSource;
  final AuthRemoteDataSource remoteDataSource;

  static const String keyCelular = 'auth_session_celular';
  static const String keyNombre = 'auth_session_nombre';
  static const String keyPin = 'auth_session_pin';
  static const String keyRole = 'auth_session_role';
  static const String keyTienda = 'auth_session_tienda';
  static const String keyActivo = 'auth_session_activo';

  AuthRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<void> seedMasterAdmins() async {
    try {
      await localDataSource.seedMasterAdmins();
      await remoteDataSource.seedMasterAdminsRemote();
    } catch (_) {
      // Non-blocking fallback
    }
  }

  @override
  Future<Either<Failure, UserModel>> login({
    required String celular,
    required String pin,
  }) async {
    try {
      final cleanCelular = celular.trim();
      final cleanPin = pin.trim();

      // 1. Search locally
      var user = await localDataSource.getUserByPhone(cleanCelular);

      // 2. If not found locally, try fetching from Firestore
      if (user == null) {
        user = await remoteDataSource.getUserByPhoneRemote(cleanCelular);
        if (user != null) {
          await localDataSource.saveUser(user);
        }
      }

      if (user == null) {
        return const Left(NotFoundFailure('Usuario no encontrado con el número proporcionado.'));
      }

      if (!user.activo) {
        return const Left(AuthFailure('El usuario se encuentra inactivo. Contacte al administrador.'));
      }

      if (user.pin != cleanPin) {
        return const Left(AuthFailure('PIN incorrecto. Verifique e intente nuevamente.'));
      }

      await saveSession(user);
      return Right(user);
    } catch (e) {
      return Left(DatabaseFailure('Error al iniciar sesión: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> registerSeller({
    required UserModel user,
    required String adminPin,
  }) async {
    try {
      final cleanAdminPin = adminPin.trim();

      // 1. Mandatory Admin Authorization PIN check
      if (!User.isValidAdminPin(cleanAdminPin)) {
        return const Left(AuthFailure('PIN de Administrador inválido. Registro rechazado'));
      }

      // 2. Strict check: Forbidden to register as admin
      if (user.role != UserRole.seller) {
        return const Left(AuthFailure('Está prohibido registrarse con rol de Administrador.'));
      }

      final cleanCelular = user.celular.trim();

      // 3. Check if phone already registered locally or remotely
      final existingLocal = await localDataSource.getUserByPhone(cleanCelular);
      if (existingLocal != null) {
        return const Left(ValidationFailure('El número de celular ya se encuentra registrado en el sistema.'));
      }

      final newSeller = user.copyWith(
        celular: cleanCelular,
        role: UserRole.seller,
        activo: true,
      );

      // a) Save in SQLite
      await localDataSource.saveUser(newSeller);

      // b) Upload to Firestore in 'users' collection
      await remoteDataSource.saveUserRemote(newSeller);

      return Right(newSeller);
    } catch (e) {
      return Left(DatabaseFailure('Error al registrar vendedor: ${e.toString()}'));
    }
  }

  @override
  Future<UserModel?> getSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final celular = prefs.getString(keyCelular);
      final nombre = prefs.getString(keyNombre);
      final pin = prefs.getString(keyPin);
      final roleStr = prefs.getString(keyRole);
      final tienda = prefs.getString(keyTienda);
      final activo = prefs.getBool(keyActivo) ?? true;

      if (celular != null && celular.isNotEmpty && roleStr != null) {
        return UserModel(
          celular: celular,
          nombre: nombre ?? '',
          pin: pin ?? '',
          role: UserRole.fromString(roleStr),
          tiendaNombre: tienda ?? 'Almacén Central',
          activo: activo,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyCelular, user.celular);
      await prefs.setString(keyNombre, user.nombre);
      await prefs.setString(keyPin, user.pin);
      await prefs.setString(keyRole, user.role.value);
      await prefs.setString(keyTienda, user.tiendaNombre);
      await prefs.setBool(keyActivo, user.activo);
    } catch (_) {}
  }

  @override
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyCelular);
      await prefs.remove(keyNombre);
      await prefs.remove(keyPin);
      await prefs.remove(keyRole);
      await prefs.remove(keyTienda);
      await prefs.remove(keyActivo);
    } catch (_) {}
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    return localDataSource.getAllUsers();
  }
}
