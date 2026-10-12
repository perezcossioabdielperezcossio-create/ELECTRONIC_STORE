import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/sync_local_datasource.dart';
import '../../data/datasources/remote_sync_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/database/database_helper.dart';

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
  StreamSubscription<List<Map<String, dynamic>>>? _remoteClientsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteDeliveriesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteUsersSubscription;
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

  /// Start real-time Firestore listeners for products, lots, sales, clients, and deliveries (Live 2-Device Sync)
  void startRealtimeSync() {
    _remoteProductsSubscription?.cancel();
    _remoteLotsSubscription?.cancel();
    _remoteSalesSubscription?.cancel();
    _remoteClientsSubscription?.cancel();
    _remoteDeliveriesSubscription?.cancel();
    _remoteUsersSubscription?.cancel();

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

    _remoteClientsSubscription = remoteDataSource.listenToRemoteClients().listen((clients) async {
      await localDataSource.syncClients(clients);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('clients'));
      notifyListeners();
    });

    _remoteDeliveriesSubscription = remoteDataSource.listenToRemoteDeliveries().listen((deliveries) async {
      await localDataSource.syncDeliveries(deliveries);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('deliveries'));
      notifyListeners();
    });

    _remoteUsersSubscription = remoteDataSource.listenToRemoteUsers().listen((users) async {
      await localDataSource.syncUsers(users);
      _remoteDataChangedController.add(null);
      _syncEventsController.add(const SyncCompletedEvent('users'));
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
    _remoteClientsSubscription?.cancel();
    _remoteDeliveriesSubscription?.cancel();
    _remoteUsersSubscription?.cancel();
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
  /// Manually force a sync cycle (useful for pull-to-refresh)
  Future<void> pullLatestChanges() async {
    await syncPendingOperations();
    if (_isOnline) {
      startRealtimeSync();
    }
  }

  Future<int> forceSyncSalesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('sales').get();
    final db = await DatabaseHelper.instance.database;
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final id = doc.id;
      final fecha = data['fecha_venta'] ?? data['created_at'] ?? DateTime.now().toIso8601String();
      final total = ((data['total_cobrado'] ?? data['total'] ?? 0) as num).toDouble();
      final metodoPago = data['metodo_pago'] ?? data['payment_method'] ?? 'EFECTIVO';
      final origen = data['origen_venta'] ?? data['store_location'] ?? data['location'] ?? 'ALMACEN';
      final tipoEntrega = data['tipo_entrega'] ?? data['delivery_method'] ?? 'TIENDA';
      final usuarioId = data['usuario_id']?.toString() ?? '';
      final status = (data['status']?.toString() ?? 'COMPLETED').toUpperCase();

      // Insertar en tabla ventas
      await db.rawInsert('''
        INSERT OR REPLACE INTO ventas (
          id, total_cobrado, metodo_pago, tipo_entrega, fecha_venta, status, is_locked, usuario_id, origen_venta
        ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
      ''', [id, total, metodoPago, tipoEntrega, fecha, status, usuarioId, origen]);

      // Procesar ítems/detalles embebidos
      final items = (data['sale_details'] ?? data['items']) as List<dynamic>? ?? [];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          await db.rawInsert('''
            INSERT OR REPLACE INTO detalle_ventas (
              id, venta_id, lote_id, product_id, cantidad, costo_unitario_compra, precio_unitario_cobrado, line_discount
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            item['id'] ?? ('${id}_${item['lote_id'] ?? item['lot_id'] ?? ''}'),
            id,
            item['lote_id'] ?? item['lot_id'] ?? '',
            item['product_id'] ?? '',
            item['cantidad'] ?? item['quantity'] ?? 1,
            ((item['costo_unitario_compra'] ?? item['unit_cost'] ?? 0) as num).toDouble(),
            ((item['precio_unitario_cobrado'] ?? item['unit_price'] ?? 0) as num).toDouble(),
            ((item['line_discount'] ?? 0) as num).toDouble(),
          ]);
        }
      }
    }
    return snapshot.docs.length;
  }
}
