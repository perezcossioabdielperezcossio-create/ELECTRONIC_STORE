import 'package:equatable/equatable.dart';

enum ReservationStatus { active, completed, expired, cancelled }

class Reservation extends Equatable {
  final String id;
  final String promoterId;
  final String productId;
  final int quantity;
  final DateTime createdAt;
  final DateTime expiresAt;
  final ReservationStatus status;

  const Reservation({
    required this.id,
    required this.promoterId,
    required this.productId,
    required this.quantity,
    required this.createdAt,
    required this.expiresAt,
    this.status = ReservationStatus.active,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Reservation copyWith({
    String? id,
    String? promoterId,
    String? productId,
    int? quantity,
    DateTime? createdAt,
    DateTime? expiresAt,
    ReservationStatus? status,
  }) {
    return Reservation(
      id: id ?? this.id,
      promoterId: promoterId ?? this.promoterId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        promoterId,
        productId,
        quantity,
        createdAt,
        expiresAt,
        status,
      ];
}
