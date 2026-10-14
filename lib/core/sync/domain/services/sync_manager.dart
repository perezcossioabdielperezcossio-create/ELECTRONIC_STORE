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
  StreamSubscription<List<Map<String, dynamic>>>? _remoteSellerSalesSubscription;
  final StreamController<void> _remoteDataChangedController = StreamController<void>.broadcast();
  final StreamController<SyncCompletedEvent> _syncEventsController = StreamController<SyncCompletedEvent>.broadcast();

  String? _currentUserRole;
  String? _currentUserCelular;

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

  /// Configures real-time synchronization according to the logged-in user role
  void configureUserSync({required String role, required String celular}) {
    _currentUserRole = role.toLowerCase().trim();
    _currentUserCelular = celular.trim();
    _configureRoleSalesSubscription();
  }

  void _configureRoleSalesSubscription() {
    _remoteSalesSubscription?.cancel();
    _remoteSalesSubscription = null;
    _remoteSellerSalesSubscription?.cancel();
    _remoteSellerSalesSubscription = null;

    final isSeller = _currentUserRole == 'seller';

    if (isSeller && _currentUserCelular != null && _currentUserCelular!.isNotEmpty) {
      // Regla 3: Si el usuario logueado es seller:
      // Escucha en vivo únicamente seller_sales con where('usuario_id', isEqualTo: currentUser.celular)
      _remoteSellerSalesSubscription = remoteDataSource.listenToSellerSales(_currentUserCelular!).listen((sellerSales) async {
        await localDataSource.syncSellerSales(sellerSales);
        _remoteDataChangedController.add(null);
        _syncEventsController.add(const SyncCompletedEvent('ventas_vendedor'));
        notifyListeners();
      });
    } else {
      // Regla 3: Si el usuario logueado es admin:
      // Escucha sales para su almacén.
      _remoteSalesSubscription = remoteDataSource.listenToRemoteSales().listen((sales) async {
        await localDataSource.syncSales(sales);
        _remoteDataChangedController.add(null);
        _syncEventsController.add(const SyncCompletedEvent('sales'));
        notifyListeners();
      });
    }
  }

  /// Start real-time Firestore listeners (Live 2-Device Sync)
  void startRealtimeSync() {
    _remoteProductsSubscription?.cancel();
    _remoteLotsSubscription?.cancel();
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

    _configureRoleSalesSubscription();

    syncPendingOperations();
  }

  /// Consulta bajo demanda de seller_sales para el Administrador (ej. Auditoría de Tiendas)
  Future<int> fetchSellerSalesOnDemand({String? sellerPhone}) async {
    final docs = await remoteDataSource.fetchSellerSales(sellerPhone: sellerPhone);
    await localDataSource.syncSellerSales(docs);
    _remoteDataChangedController.add(null);
    _syncEventsController.add(const SyncCompletedEvent('ventas_vendedor'));
    notifyListeners();
    return docs.length;
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
    _remoteSellerSalesSubscription?.cancel();
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

  Future<int> forceSyncAllSalesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('sales').get();
      final db = await DatabaseHelper.instance.database;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final fecha = data['fecha_venta'] ?? data['created_at'] ?? DateTime.now().toIso8601String();
        final total = ((data['total_cobrado'] ?? data['total'] ?? data['unit_price'] ?? 0) as num).toDouble();
        final metodoPago = data['metodo_pago'] ?? data['payment_method'] ?? 'EFECTIVO';
        final tipoEntrega = data['tipo_entrega'] ?? data['delivery_method'] ?? 'TIENDA';
        final usuarioId = data['usuario_id']?.toString() ?? '';
        final clienteNombre = (data['customer_name'] ?? data['cliente_nombre'] ?? 'Cliente Mostrador').toString();
        final origen = data['origen_venta'] ?? data['store_location'] ?? data['location'] ?? 'ALMACEN';
        final rawStatus = (data['status']?.toString() ?? 'COMPLETED').toUpperCase();
        final status = (rawStatus == 'PENDING' || rawStatus == 'COMPLETED') ? 'COMPLETED' : rawStatus;

        // 1. Insertar venta cabecera
        await db.rawInsert('''
          INSERT OR REPLACE INTO ventas (
            id, total_cobrado, metodo_pago, tipo_entrega, fecha_venta, status, is_locked, usuario_id, origen_venta
          ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
        ''', [id, total, metodoPago, tipoEntrega, fecha, status, usuarioId, origen]);

        if (clienteNombre.isNotEmpty) {
          try {
            await db.rawUpdate(
              'UPDATE ventas SET customer_name = ?, cliente_nombre = ? WHERE id = ?',
              [clienteNombre, clienteNombre, id],
            );
          } catch (_) {
            try {
              await db.rawUpdate('UPDATE ventas SET customer_name = ? WHERE id = ?', [clienteNombre, id]);
            } catch (_) {}
          }
        }

        // Helper to insert a detail record into detalle_ventas
        Future<void> insertDetailRow({
          required String detailId,
          required String ventaId,
          String? loteId,
          required String prodId,
          required String prodName,
          required int cantidad,
          required double costo,
          required double precio,
          required double descuento,
        }) async {
          final lot = loteId ?? '';
          try {
            await db.rawInsert('''
              INSERT OR REPLACE INTO detalle_ventas (
                id, venta_id, lote_id, product_id, cantidad, costo_unitario_compra, precio_unitario_cobrado, line_discount
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', [detailId, ventaId, lot, prodId, cantidad, costo, precio, descuento]);
          } catch (_) {
            try {
              await db.rawInsert('''
                INSERT OR REPLACE INTO detalle_ventas (
                  id, venta_id, lote_id, producto_id, cantidad, costo_unitario_compra, precio_unitario_cobrado, line_discount
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ''', [detailId, ventaId, lot, prodId, cantidad, costo, precio, descuento]);
            } catch (_) {}
          }

          if (prodId.isNotEmpty) {
            try {
              await db.rawUpdate('UPDATE detalle_ventas SET producto_id = ? WHERE id = ?', [prodId, detailId]);
            } catch (_) {}
          }

          if (prodName.isNotEmpty) {
            try {
              await db.rawUpdate('UPDATE detalle_ventas SET product_name = ? WHERE id = ?', [prodName, detailId]);
            } catch (_) {}
          }
        }

        int insertedDetailsCount = 0;

        // 2. Extracción Robusta de Detalles:
        // A. Si doc.data()['sale_details'] o doc.data()['items'] es una lista no vacía:
        final dynamic rawDetails = data['sale_details'] ?? data['items'];
        if (rawDetails is List && rawDetails.isNotEmpty) {
          for (var i = 0; i < rawDetails.length; i++) {
            final rawItem = rawDetails[i];
            if (rawItem is Map) {
              final item = Map<String, dynamic>.from(rawItem);
              final detailId = (item['id'] ?? '${id}_det_$i').toString();
              final prodId = (item['product_id'] ?? item['producto_id'] ?? '').toString();
              final prodName = (item['product_name'] ?? item['name'] ?? 'Venta Mostrador').toString();
              final loteId = (item['lote_id'] ?? item['lot_id'] ?? '').toString();
              final cantidad = ((item['cantidad'] ?? item['quantity'] ?? 1) as num).toInt();
              final costo = ((item['costo_unitario_compra'] ?? item['unit_cost'] ?? 0) as num).toDouble();
              final precio = ((item['precio_unitario_cobrado'] ?? item['unit_price'] ?? total) as num).toDouble();
              final descuento = ((item['line_discount'] ?? item['descuento'] ?? 0) as num).toDouble();

              await insertDetailRow(
                detailId: detailId,
                ventaId: id,
                loteId: loteId,
                prodId: prodId,
                prodName: prodName,
                cantidad: cantidad,
                costo: costo,
                precio: precio,
                descuento: descuento,
              );
              insertedDetailsCount++;
            }
          }
        }

        // B. Si no viene como lista embebida, consultar la subcolección sale_details
        if (insertedDetailsCount == 0) {
          try {
            final detailsSnap = await doc.reference.collection('sale_details').get();
            if (detailsSnap.docs.isNotEmpty) {
              for (final dDoc in detailsSnap.docs) {
                final dData = dDoc.data();
                final prodId = (dData['product_id'] ?? dData['producto_id'] ?? '').toString();
                final prodName = (dData['product_name'] ?? dData['name'] ?? 'Venta Mostrador').toString();
                final loteId = (dData['lote_id'] ?? dData['lot_id'] ?? '').toString();
                final cantidad = ((dData['cantidad'] ?? dData['quantity'] ?? 1) as num).toInt();
                final costo = ((dData['costo_unitario_compra'] ?? dData['unit_cost'] ?? 0) as num).toDouble();
                final precio = ((dData['precio_unitario_cobrado'] ?? dData['unit_price'] ?? total) as num).toDouble();
                final descuento = ((dData['line_discount'] ?? 0) as num).toDouble();

                await insertDetailRow(
                  detailId: dDoc.id,
                  ventaId: id,
                  loteId: loteId,
                  prodId: prodId,
                  prodName: prodName,
                  cantidad: cantidad,
                  costo: costo,
                  precio: precio,
                  descuento: descuento,
                );
                insertedDetailsCount++;
              }
            }
          } catch (_) {}
        }

        // C. Si no tiene ningún detalle, generar un renglón por defecto en detalle_ventas:
        if (insertedDetailsCount == 0) {
          await insertDetailRow(
            detailId: '${id}_det',
            ventaId: id,
            loteId: '',
            prodId: '',
            prodName: 'Venta Mostrador',
            cantidad: 1,
            costo: 0.0,
            precio: total,
            descuento: 0.0,
          );
        }
      }

      _syncEventsController.add(const SyncCompletedEvent('sales'));
      notifyListeners();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('forceSyncAllSalesFromFirestore error: $e');
      return 0;
    }
  }

  Future<int> forceSyncSalesFromFirestore() => forceSyncAllSalesFromFirestore();
}
