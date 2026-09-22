import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/sync_local_datasource.dart';
import '../../data/datasources/remote_sync_datasource.dart';

class SyncManager {
  final SyncLocalDataSource localDataSource;
  final RemoteSyncDataSource remoteDataSource;
  
  bool _isSyncing = false;
  bool _isOnline = true; // Assuming online initially, in a real app listen to connectivity_plus

  SyncManager({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  /// Updates network status and triggers sync if online
  void updateNetworkStatus(bool isOnline) {
    _isOnline = isOnline;
    if (_isOnline) {
      syncPendingOperations();
    }
  }

  /// Manually trigger synchronization
  Future<void> syncPendingOperations() async {
    if (_isSyncing || !_isOnline) return;
    
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
    }
  }
}
