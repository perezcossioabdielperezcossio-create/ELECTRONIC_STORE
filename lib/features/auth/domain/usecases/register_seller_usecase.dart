import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

class RegisterSellerUseCase {
  final AuthRepository repository;

  RegisterSellerUseCase(this.repository);

  Future<Either<Failure, UserModel>> call({
    required UserModel user,
    required String adminPin,
  }) {
    return repository.registerSeller(user: user, adminPin: adminPin);
  }
}
