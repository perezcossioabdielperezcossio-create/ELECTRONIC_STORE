import '../repositories/auth_repository.dart';

class SeedMasterAdminsUseCase {
  final AuthRepository repository;

  SeedMasterAdminsUseCase(this.repository);

  Future<void> call() {
    return repository.seedMasterAdmins();
  }
}
