import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

class GetCurrentSessionUseCase {
  final AuthRepository repository;

  GetCurrentSessionUseCase(this.repository);

  Future<UserModel?> call() {
    return repository.getSavedSession();
  }
}
