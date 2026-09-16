import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDatasource localDatasource;
  const DashboardRepositoryImpl(this.localDatasource);

  @override
  Future<Either<Failure, DashboardSummary>> getSummary(DateTime date) async {
    try {
      return Right(await localDatasource.getSummary(date));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }
}
