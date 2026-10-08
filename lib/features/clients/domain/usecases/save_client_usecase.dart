import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class SaveClientUseCase implements UseCase<Client, Client> {
  final ClientRepository repository;

  SaveClientUseCase(this.repository);

  @override
  Future<Either<Failure, Client>> call(Client client) {
    return repository.saveClient(client);
  }
}
