import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/reservation.dart';
import '../repositories/promoter_repository.dart';

class CreateReservation implements UseCase<Unit, CreateReservationParams> {
  final PromoterRepository repository;

  CreateReservation(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CreateReservationParams params) async {
    final now = DateTime.now();
    final reservation = Reservation(
      id: const Uuid().v4(),
      promoterId: params.promoterId,
      productId: params.productId,
      quantity: params.quantity,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      status: ReservationStatus.active,
    );

    return await repository.createReservation(reservation);
  }
}

class CreateReservationParams extends Equatable {
  final String promoterId;
  final String productId;
  final int quantity;

  const CreateReservationParams({
    required this.promoterId,
    required this.productId,
    required this.quantity,
  });

  @override
  List<Object> get props => [promoterId, productId, quantity];
}
