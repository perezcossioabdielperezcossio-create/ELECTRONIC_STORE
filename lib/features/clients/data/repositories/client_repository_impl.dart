import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_local_datasource.dart';
import '../models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientLocalDataSource localDataSource;

  ClientRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, List<Client>>> getAllClients() async {
    try {
      final clients = await localDataSource.getAllClients();
      return Right(clients);
    } catch (e) {
      return Left(DatabaseFailure('Error al cargar clientes: $e'));
    }
  }

  @override
  Future<Either<Failure, Client?>> getClientById(String id) async {
    try {
      final client = await localDataSource.getClientById(id);
      return Right(client);
    } catch (e) {
      return Left(DatabaseFailure('Error al buscar cliente: $e'));
    }
  }

  @override
  Future<Either<Failure, Client>> saveClient(Client client) async {
    try {
      final model = ClientModel.fromEntity(client);
      await localDataSource.saveClient(model);
      return Right(model);
    } catch (e) {
      return Left(DatabaseFailure('Error al guardar cliente: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Client>>> searchClients(String query) async {
    try {
      final clients = await localDataSource.searchClients(query);
      return Right(clients);
    } catch (e) {
      return Left(DatabaseFailure('Error al buscar clientes: $e'));
    }
  }
}
