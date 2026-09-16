import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sale.dart';
import '../repositories/pos_repository.dart';

class CreateSale implements UseCase<Unit, CreateSaleParams> {
  final PosRepository repository;
  const CreateSale(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CreateSaleParams params) =>
      repository.saveSale(params.sale);
}

class CreateSaleParams extends Equatable {
  final Sale sale;
  const CreateSaleParams(this.sale);
  @override
  List<Object> get props => [sale];
}
