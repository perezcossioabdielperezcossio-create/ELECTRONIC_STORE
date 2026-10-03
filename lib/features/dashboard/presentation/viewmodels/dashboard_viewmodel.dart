import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/usecases/get_financial_overview_usecase.dart';
import '../../domain/usecases/get_daily_cash_audit_usecase.dart';
import '../../data/models/financial_metrics_model.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/domain/usecases/get_sales_by_date.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';

enum DashboardState { initial, loading, loaded, error }

class DashboardViewModel extends ChangeNotifier {
  final GetFinancialOverviewUseCase getFinancialOverview;
  final GetDailyCashAuditUseCase getDailyCashAudit;
  final GetSalesByDate? getSalesByDate;
  final SyncManager? syncManager;

  StreamSubscription? _syncSubscription;

  DashboardState _state = DashboardState.initial;
  DashboardState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  FinancialOverviewResult? _overview;
  FinancialOverviewResult? get overview => _overview;

  ArqueoDiario? _arqueoDiario;
  ArqueoDiario? get arqueoDiario => _arqueoDiario;

  List<Sale> _dailySales = [];
  List<Sale> get dailySales => List.unmodifiable(_dailySales);

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  DashboardViewModel({
    required this.getFinancialOverview,
    required this.getDailyCashAudit,
    this.getSalesByDate,
    this.syncManager,
  }) {
    _initSyncListener();
  }

  void _initSyncListener() {
    _syncSubscription = syncManager?.onRemoteDataChanged.listen((_) {
      loadDashboardData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardData() async {
    _state = DashboardState.loading;
    notifyListeners();

    final overviewResult = await getFinancialOverview();
    final arqueoResult = await getDailyCashAudit(date: _selectedDate);

    if (getSalesByDate != null) {
      final salesResult = await getSalesByDate!(DateParams(_selectedDate));
      salesResult.fold(
        (_) => _dailySales = [],
        (sales) => _dailySales = sales,
      );
    }

    overviewResult.fold(
      (failure) {
        _errorMessage = failure.message;
        _state = DashboardState.error;
      },
      (data) {
        _overview = data;
        arqueoResult.fold(
          (failure) {
            _errorMessage = failure.message;
            _state = DashboardState.error;
          },
          (arqueoData) {
            _arqueoDiario = arqueoData;
            _state = DashboardState.loaded;
            _errorMessage = null;
          },
        );
      },
    );

    notifyListeners();
  }

  Future<void> changeDate(DateTime newDate) async {
    _selectedDate = newDate;
    await loadDashboardData();
  }
}
