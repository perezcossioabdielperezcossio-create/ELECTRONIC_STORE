import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sale.dart';
import '../repositories/pos_repository.dart';

class ProcessSaleUseCase implements UseCase<Unit, ProcessSaleParams> {
  final PosRepository repository;

  ProcessSaleUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ProcessSaleParams params) async {
    return await repository.processSale(params.sale);
  }
}

class ProcessSaleParams {
  final Sale sale;

  const ProcessSaleParams(this.sale);
}
