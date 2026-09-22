import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/sync_local_datasource.dart';
import '../../data/datasources/remote_sync_datasource.dart';

class SyncManager extends ChangeNotifier {
  final SyncLocalDataSource localDataSource;
  final RemoteSyncDataSource remoteDataSource;
  
  bool _isSyncing = false;
  bool _isOnline = true; // Assuming online initially, in a real app listen to connectivity_plus
  int _pendingCount = 0;

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;

  SyncManager({
    required this.localDataSource,
    required this.remoteDataSource,
  }) {
    _refreshPendingCount();
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
        final result = await remoteDataSource.syncOperation(operation);
        
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
