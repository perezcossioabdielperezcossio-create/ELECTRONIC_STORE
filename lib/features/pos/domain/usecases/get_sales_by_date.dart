import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sale.dart';
import '../repositories/pos_repository.dart';

class GetSalesByDate implements UseCase<List<Sale>, DateParams> {
  final PosRepository repository;
  const GetSalesByDate(this.repository);

  @override
  Future<Either<Failure, List<Sale>>> call(DateParams params) =>
      repository.getSalesByDate(params.date);
}

class DateParams extends Equatable {
  final DateTime date;
  const DateParams(this.date);
  @override
  List<Object> get props => [date];
}
