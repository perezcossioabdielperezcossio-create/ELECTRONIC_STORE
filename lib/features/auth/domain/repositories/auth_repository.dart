import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> login({
    required String celular,
    required String pin,
  });

  Future<Either<Failure, UserModel>> registerSeller({
    required UserModel user,
    required String adminPin,
  });

  Future<UserModel?> getSavedSession();

  Future<void> saveSession(UserModel user);

  Future<void> clearSession();

  Future<void> seedMasterAdmins();

  Future<List<UserModel>> getAllUsers();
}
