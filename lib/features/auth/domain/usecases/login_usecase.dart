import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, UserModel>> call({
    required String celular,
    required String pin,
  }) {
    return repository.login(celular: celular, pin: pin);
  }
}
