import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Contrato base para todos los UseCases.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Usar cuando el UseCase no requiere parámetros.
class NoParams {
  const NoParams();
}
