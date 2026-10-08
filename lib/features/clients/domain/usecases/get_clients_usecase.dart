import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class GetClientsUseCase implements UseCase<List<Client>, NoParams> {
  final ClientRepository repository;

  GetClientsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Client>>> call(NoParams params) {
    return repository.getAllClients();
  }
}
