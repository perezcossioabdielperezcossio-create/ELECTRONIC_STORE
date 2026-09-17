import 'package:flutter/foundation.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary.dart';

class DashboardViewModel extends ChangeNotifier {
  final GetDashboardSummary getSummary;
  DashboardViewModel({required this.getSummary});

  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  DashboardSummary? get summary   => _summary;
  bool              get isLoading => _isLoading;
  String?           get error     => _error;

  Future<void> load([DateTime? date]) async {
    _isLoading = true; notifyListeners();
    final result = await getSummary(DashboardParams(date ?? DateTime.now()));
    result.fold(
      (f) { _error = f.message; },
      (s) { _summary = s; _error = null; },
    );
    _isLoading = false; notifyListeners();
  }
}
