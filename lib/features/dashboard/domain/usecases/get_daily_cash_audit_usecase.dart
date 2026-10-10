import '../repositories/dashboard_repository.dart';
import '../../data/models/financial_metrics_model.dart';
import '../../../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';

class GetDailyCashAuditUseCase {
  final DashboardRepository repository;

  GetDailyCashAuditUseCase(this.repository);

  Future<Either<Failure, ArqueoDiario>> call({
    DateTime? date,
    String? usuarioId,
    String? origenVenta,
  }) async {
    try {
      final arqueo = await repository.getArqueoDiario(
        date: date,
        usuarioId: usuarioId,
        origenVenta: origenVenta,
      );
      return Right(arqueo);
    } catch (e) {
      return Left(DatabaseFailure('Error obteniendo el arqueo diario: ${e.toString()}'));
    }
  }
}
