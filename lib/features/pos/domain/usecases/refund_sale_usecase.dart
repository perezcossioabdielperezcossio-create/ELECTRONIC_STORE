import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/pos_repository.dart';

class RefundSaleUseCase {
  final PosRepository repository;

  RefundSaleUseCase(this.repository);

  Future<Either<Failure, Unit>> call(String saleId) async {
    return await repository.refundSale(saleId);
  }
}
