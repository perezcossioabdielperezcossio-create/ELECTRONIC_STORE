import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/client.dart';

abstract class ClientRepository {
  Future<Either<Failure, List<Client>>> getAllClients();
  Future<Either<Failure, Client?>> getClientById(String id);
  Future<Either<Failure, Client>> saveClient(Client client);
  Future<Either<Failure, List<Client>>> searchClients(String query);
}
