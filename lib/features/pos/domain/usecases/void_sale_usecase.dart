import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/pos_repository.dart';

class VoidSaleUseCase implements UseCase<Unit, String> {
  final PosRepository repository;

  VoidSaleUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String saleId) async {
    final saleEither = await repository.getSaleById(saleId);
    
    return saleEither.fold(
      (failure) => Left(failure),
      (sale) async {
        final now = DateTime.now().toUtc();
        final saleDate = sale.createdAt.toUtc();
        final diff = now.difference(saleDate);

        if (diff.inHours >= 24) {
          return const Left(ValidationFailure('Han pasado más de 24 horas. Inmutabilidad contable activa.'));
        }
        
        return await repository.voidSale(saleId);
      },
    );
  }
}
