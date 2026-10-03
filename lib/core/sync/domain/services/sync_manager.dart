import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/sync_local_datasource.dart';
import '../../data/datasources/remote_sync_datasource.dart';

class SyncManager extends ChangeNotifier {
  final SyncLocalDataSource localDataSource;
  final RemoteSyncDataSource remoteDataSource;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteProductsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteLotsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteSalesSubscription;
  final StreamController<void> _remoteDataChangedController = StreamController<void>.broadcast();

  bool _isSyncing = false;
  bool _isOnline = true; // Will be updated by connectivity_plus
  int _pendingCount = 0;

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;
  Stream<void> get onRemoteDataChanged => _remoteDataChangedController.stream;

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
      notifyListeners();
    });

    _remoteLotsSubscription = remoteDataSource.listenToRemoteLots().listen((lots) async {
      await localDataSource.syncLots(lots);
      _remoteDataChangedController.add(null);
      notifyListeners();
    });

    _remoteSalesSubscription = remoteDataSource.listenToRemoteSales().listen((sales) async {
      await localDataSource.syncSales(sales);
      _remoteDataChangedController.add(null);
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

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _remoteProductsSubscription?.cancel();
    _remoteLotsSubscription?.cancel();
    _remoteSalesSubscription?.cancel();
    _remoteDataChangedController.close();
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
    final pendingOps = await localDataSource.getPendingOperations();
    if (_pendingCount != pendingOps.length) {
      _pendingCount = pendingOps.length;
      notifyListeners();
    }
  }

  /// Manually trigger synchronization
  Future<void> syncPendingOperations() async {
    await _refreshPendingCount();
    
    if (_isSyncing || !_isOnline || _pendingCount == 0) return;
    
    _isSyncing = true;
    
    try {
      final pendingOperations = await localDataSource.getPendingOperations();
      
      for (final operation in pendingOperations) {
        // Sequential processing (FIFO)
        final result = await remoteDataSource.syncOperation(operation).timeout(
          const Duration(seconds: 10),
          onTimeout: () => SyncResult(success: false, errorMessage: 'Timeout de conexión'),
        );
        
        if (result.success) {
          // If conflict was resolved with newer data from remote, we might update local DB here
          // But for this requirement, we just mark as synced.
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
      await _refreshPendingCount();
    }
  }
}
