import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/sale.dart';

abstract class PosRepository {
  Future<Either<Failure, Unit>>       saveSale(Sale sale);
  Future<Either<Failure, Sale>>       getSaleById(String id);
  Future<Either<Failure, List<Sale>>> getSalesByDate(DateTime date);
  Future<Either<Failure, Unit>>       voidSale(String id);
}
