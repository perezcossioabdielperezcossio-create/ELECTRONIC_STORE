import 'package:equatable/equatable.dart';

class Commission extends Equatable {
  final String id;
  final String promoterId;
  final String saleId;
  final double saleTotal;
  final double rate;
  final double amount;
  final DateTime calculatedAt;
  final bool isPaid;

  const Commission({
    required this.id,
    required this.promoterId,
    required this.saleId,
    required this.saleTotal,
    required this.rate,
    required this.amount,
    required this.calculatedAt,
    this.isPaid = false,
  });

  @override
  List<Object> get props =>
      [id, promoterId, saleId, saleTotal, rate, amount, calculatedAt, isPaid];
}
