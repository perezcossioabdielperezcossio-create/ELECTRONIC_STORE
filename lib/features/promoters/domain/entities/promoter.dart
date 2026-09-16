import 'package:equatable/equatable.dart';

class Promoter extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final double commissionRate; // porcentaje 0-100
  final bool isActive;

  const Promoter({
    required this.id,
    required this.name,
    required this.phone,
    required this.commissionRate,
    this.email,
    this.isActive = true,
  });

  @override
  List<Object?> get props =>
      [id, name, phone, email, commissionRate, isActive];
}
