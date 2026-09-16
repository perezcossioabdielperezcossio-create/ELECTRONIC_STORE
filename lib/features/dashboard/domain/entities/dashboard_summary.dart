import 'package:equatable/equatable.dart';

class DashboardSummary extends Equatable {
  final double todaySales;
  final int    transactionCount;
  final int    lowStockCount;
  final double pendingCommissions;

  const DashboardSummary({
    required this.todaySales,
    required this.transactionCount,
    required this.lowStockCount,
    required this.pendingCommissions,
  });

  @override
  List<Object> get props =>
      [todaySales, transactionCount, lowStockCount, pendingCommissions];
}
