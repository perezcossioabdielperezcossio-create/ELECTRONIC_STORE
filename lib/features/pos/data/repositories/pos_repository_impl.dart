import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../datasources/pos_local_datasource.dart';
import '../models/sale_model.dart';

class PosRepositoryImpl implements PosRepository {
  final PosLocalDatasource localDatasource;
  const PosRepositoryImpl(this.localDatasource);

  @override
  Future<Either<Failure, Unit>> saveSale(Sale sale) async {
    try {
      await localDatasource.saveSale(SaleModel(
        id:         sale.id,
        items:      sale.items,
        createdAt:  sale.createdAt,
        discount:   sale.discount,
        tax:        sale.tax,
        status:     sale.status,
        promoterId: sale.promoterId,
        notes:      sale.notes,
      ));
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> processSale(Sale sale) async {
    try {
      await localDatasource.processSale(SaleModel(
        id:         sale.id,
        items:      sale.items,
        createdAt:  sale.createdAt,
        discount:   sale.discount,
        tax:        sale.tax,
        status:     sale.status,
        promoterId: sale.promoterId,
        notes:      sale.notes,
      ));
      return const Right(unit);
    } on AntiLossException catch (e) {
      return Left(ValidationFailure(e.message));
    } on InsufficientStockException catch (e) {
      return Left(ValidationFailure(e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Sale>> getSaleById(String id) async {
    try {
      return Right(await localDatasource.getSaleById(id));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getSalesByDate(DateTime date) async {
    try {
      return Right(await localDatasource.getSalesByDate(date));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> voidSale(String id) async {
    try {
      await localDatasource.voidSale(id);
      return const Right(unit);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> refundSale(String saleId) async {
    try {
      await localDatasource.refundSale(saleId);
      return const Right(unit);
    } on RefundWindowExpiredException catch (e) {
      return Left(ValidationFailure(e.message));
    } on SaleLockedException catch (e) {
      return Left(ValidationFailure(e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
