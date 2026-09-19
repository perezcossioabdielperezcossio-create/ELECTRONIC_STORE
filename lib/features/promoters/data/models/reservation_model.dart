import '../../domain/entities/reservation.dart';

class ReservationModel extends Reservation {
  const ReservationModel({
    required super.id,
    required super.promoterId,
    required super.productId,
    required super.quantity,
    required super.createdAt,
    required super.expiresAt,
    super.status,
  });

  factory ReservationModel.fromMap(Map<String, dynamic> map) {
    return ReservationModel(
      id: map['id'] as String,
      promoterId: map['promoter_id'] as String,
      productId: map['product_id'] as String,
      quantity: map['quantity'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      status: _parseStatus(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'promoter_id': promoterId,
      'product_id': productId,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status.name.toUpperCase(),
    };
  }

  static ReservationStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'COMPLETED':
        return ReservationStatus.completed;
      case 'EXPIRED':
        return ReservationStatus.expired;
      case 'CANCELLED':
        return ReservationStatus.cancelled;
      case 'ACTIVE':
      default:
        return ReservationStatus.active;
    }
  }
}
