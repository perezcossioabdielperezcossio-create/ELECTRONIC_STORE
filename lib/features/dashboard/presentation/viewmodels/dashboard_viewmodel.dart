import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/usecases/get_financial_overview_usecase.dart';
import '../../domain/usecases/get_daily_cash_audit_usecase.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../data/models/financial_metrics_model.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/domain/usecases/get_sales_by_date.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';

enum DashboardState { initial, loading, loaded, error }

enum AdminDashboardFilter {
  almacenCentral,
  consolidadoGeneral,
  porVendedor,
}

class DashboardViewModel extends ChangeNotifier {
  final GetFinancialOverviewUseCase getFinancialOverview;
  final GetDailyCashAuditUseCase getDailyCashAudit;
  final GetSalesByDate? getSalesByDate;
  final SyncManager? syncManager;
  final DashboardRepository? dashboardRepository;

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

  // Admin Filters
  AdminDashboardFilter _adminFilter = AdminDashboardFilter.almacenCentral;
  AdminDashboardFilter get adminFilter => _adminFilter;

  String? _selectedSellerPhone;
  String? get selectedSellerPhone => _selectedSellerPhone;

  List<User> _sellers = [];
  List<User> get sellers => List.unmodifiable(_sellers);

  // Seller Dashboard Metrics
  double _sellerVentasHoy = 0.0;
  double get sellerVentasHoy => _sellerVentasHoy;

  double _sellerVentasSemana = 0.0;
  double get sellerVentasSemana => _sellerVentasSemana;

  ArqueoDiario? _sellerArqueo;
  ArqueoDiario? get sellerArqueo => _sellerArqueo;

  List<Sale> _sellerSales = [];
  List<Sale> get sellerSales => List.unmodifiable(_sellerSales);

  bool _isSellerLoading = false;
  bool get isSellerLoading => _isSellerLoading;

  String? _sellerErrorMessage;
  String? get sellerErrorMessage => _sellerErrorMessage;

  DashboardViewModel({
    required this.getFinancialOverview,
    required this.getDailyCashAudit,
    this.getSalesByDate,
    this.syncManager,
    this.dashboardRepository,
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

  Future<void> loadSellers() async {
    if (dashboardRepository != null) {
      try {
        _sellers = await dashboardRepository!.getSellers();
        if (_sellers.isNotEmpty && _selectedSellerPhone == null) {
          _selectedSellerPhone = _sellers.first.celular;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error cargando vendedores: $e');
      }
    }
  }

  Future<void> setAdminFilter(AdminDashboardFilter filter) async {
    _adminFilter = filter;
    if (filter == AdminDashboardFilter.porVendedor && _sellers.isEmpty) {
      await loadSellers();
    }
    await loadDashboardData();
  }

  Future<void> setSelectedSellerPhone(String? phone) async {
    _selectedSellerPhone = phone;
    if (_adminFilter == AdminDashboardFilter.porVendedor) {
      await loadDashboardData();
    }
  }

  Future<void> loadDashboardData() async {
    _state = DashboardState.loading;
    notifyListeners();

    String? filterOrigen;
    String? filterUsuarioId;

    switch (_adminFilter) {
      case AdminDashboardFilter.almacenCentral:
        filterOrigen = 'ALMACEN';
        filterUsuarioId = null;
        break;
      case AdminDashboardFilter.consolidadoGeneral:
        filterOrigen = null;
        filterUsuarioId = null;
        break;
      case AdminDashboardFilter.porVendedor:
        filterOrigen = 'TIENDA';
        filterUsuarioId = _selectedSellerPhone;
        break;
    }

    final overviewResult = await getFinancialOverview(origenVenta: filterOrigen);
    final arqueoResult = await getDailyCashAudit(
      date: _selectedDate,
      usuarioId: filterUsuarioId,
      origenVenta: filterOrigen,
    );

    if (dashboardRepository != null) {
      try {
        _dailySales = await dashboardRepository!.getVentasFiltradas(
          date: _selectedDate,
          usuarioId: filterUsuarioId,
          origenVenta: filterOrigen,
        );
      } catch (_) {
        if (getSalesByDate != null) {
          final salesResult = await getSalesByDate!(DateParams(_selectedDate));
          salesResult.fold(
            (_) => _dailySales = [],
            (sales) => _dailySales = sales,
          );
        }
      }
    } else if (getSalesByDate != null) {
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

  Future<void> loadSellerDashboardData(String usuarioId) async {
    _isSellerLoading = true;
    _sellerErrorMessage = null;
    notifyListeners();

    try {
      if (dashboardRepository != null) {
        final arqueo = await dashboardRepository!.getArqueoDiario(
          date: _selectedDate,
          usuarioId: usuarioId,
          origenVenta: 'TIENDA',
        );
        final ventasSemana = await dashboardRepository!.getTotalVentasSemana(
          date: _selectedDate,
          usuarioId: usuarioId,
          origenVenta: 'TIENDA',
        );
        final sales = await dashboardRepository!.getVentasFiltradas(
          date: _selectedDate,
          usuarioId: usuarioId,
          origenVenta: 'TIENDA',
        );

        _sellerArqueo = arqueo;
        _sellerVentasHoy = arqueo.totalIngresos;
        _sellerVentasSemana = ventasSemana;
        _sellerSales = sales;
      } else {
        final arqueoResult = await getDailyCashAudit(
          date: _selectedDate,
          usuarioId: usuarioId,
          origenVenta: 'TIENDA',
        );
        arqueoResult.fold(
          (failure) {
            _sellerErrorMessage = failure.message;
          },
          (arqueoData) {
            _sellerArqueo = arqueoData;
            _sellerVentasHoy = arqueoData.totalIngresos;
          },
        );
      }
    } catch (e) {
      _sellerErrorMessage = 'Error cargando datos del vendedor: $e';
    } finally {
      _isSellerLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeDate(DateTime newDate, {String? sellerUsuarioId}) async {
    _selectedDate = newDate;
    if (sellerUsuarioId != null) {
      await loadSellerDashboardData(sellerUsuarioId);
    } else {
      await loadDashboardData();
    }
  }
}
