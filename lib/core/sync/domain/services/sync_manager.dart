import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/sync_local_datasource.dart';
import '../../data/datasources/remote_sync_datasource.dart';

class SyncCompletedEvent {
  final String table;
  final dynamic data;
  const SyncCompletedEvent(this.table, [this.data]);
}

class SyncManager extends ChangeNotifier {
  final SyncLocalDataSource localDataSource;
  final RemoteSyncDataSource remoteDataSource;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteProductsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteLotsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteSalesSubscription;
  final StreamController<void> _remoteDataChangedController = StreamController<void>.broadcast();
  final StreamController<SyncCompletedEvent> _syncEventsController = StreamController<SyncCompletedEvent>.broadcast();

  bool _isSyncing = false;
  bool _isOnline = true; // Will be updated by connectivity_plus
  int _pendingCount = 0;

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;
  Stream<void> get onRemoteDataChanged => _remoteDataChangedController.stream;
  Stream<SyncCompletedEvent> get onSyncCompleted => _syncEventsController.stream;

  SyncManager({
    required this.localDataSource,
    required this.remoteDataSource,
  }) {
    _initConnectivity();
    _refreshPendingCount();
  }

  /// Start real-time Firestore listeners for products, lots, and sales (Live 2-Device Sync)
  void startRealtimeSync() {
    _remoteProductsSubscription?.cancel();
    _remoteLotsSubscription?.cancel();
    _remoteSalesSubscription?.cancel();

    _remoteProductsSubscription = remoteDataSource.listenToRemoteProducts().listen((products) async {
      await localDataSource.syncProducts(products);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('products'));
      notifyListeners();
    });

    _remoteLotsSubscription = remoteDataSource.listenToRemoteLots().listen((lots) async {
      await localDataSource.syncLots(lots);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('lots'));
      notifyListeners();
    });

    _remoteSalesSubscription = remoteDataSource.listenToRemoteSales().listen((sales) async {
      await localDataSource.syncSales(sales);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('sales'));
      notifyListeners();
    });

    syncPendingOperations();
  }

  void initialize() {
    startRealtimeSync();
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      updateNetworkStatus(isConnected);
    });
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _remoteProductsSubscription?.cancel();
    _remoteLotsSubscription?.cancel();
    _remoteSalesSubscription?.cancel();
    _remoteDataChangedController.close();
    _syncEventsController.close();
    super.dispose();
  }

  /// Updates network status and triggers sync if online
  void updateNetworkStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    }
    if (_isOnline) {
      syncPendingOperations();
    }
  }

  Future<void> _refreshPendingCount() async {
    if (_isDisposed) return;
    try {
      final pendingOps = await localDataSource.getPendingOperations();
      if (_isDisposed) return;
      if (_pendingCount != pendingOps.length) {
        _pendingCount = pendingOps.length;
        notifyListeners();
      }
    } catch (_) {
      // Ignore database closure during shutdown/test teardown
    }
  }

  /// Manually trigger synchronization
  Future<void> syncPendingOperations() async {
    if (_isDisposed) return;
    await _refreshPendingCount();
    
    if (_isSyncing || !_isOnline || _pendingCount == 0 || _isDisposed) return;
    
    _isSyncing = true;
    
    try {
      final pendingOperations = await localDataSource.getPendingOperations();
      
      for (final operation in pendingOperations) {
        if (_isDisposed) break;
        // Sequential processing (FIFO)
        final result = await remoteDataSource.syncOperation(operation).timeout(
          const Duration(seconds: 10),
          onTimeout: () => SyncResult(success: false, errorMessage: 'Timeout de conexión'),
        );
        
        if (_isDisposed) break;
        if (result.success) {
          await localDataSource.markAsSynced(operation.id);
        } else {
          await localDataSource.markAsFailed(operation.id, result.errorMessage ?? 'Unknown error');
        }
      }
    } catch (e) {
      // Handle fatal sync errors
      debugPrint('SyncManager error: $e');
    } finally {
      _isSyncing = false;
      if (!_isDisposed) {
        await _refreshPendingCount();
      }
    }
  }
}
