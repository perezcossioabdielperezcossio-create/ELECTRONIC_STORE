import '../models/sync_operation_model.dart';

/// Define the outcome of a remote sync operation.
class SyncResult {
  final bool success;
  final bool conflictResolved; // true if conflict was resolved by First-Write-Wins and remote was newer
  final String? errorMessage;
  final SyncOperationModel? updatedOperation; // populated if conflict resolved with newer data

  SyncResult({
    required this.success,
    this.conflictResolved = false,
    this.errorMessage,
    this.updatedOperation,
  });
}

abstract class RemoteSyncDataSource {
  Future<SyncResult> syncOperation(SyncOperationModel operation);
}

class MockRemoteSyncDataSource implements RemoteSyncDataSource {
  @override
  Future<SyncResult> syncOperation(SyncOperationModel operation) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Try to extract an ID from payload to mock conflict resolution
    // Note: This is simplified. In a real app we'd parse the payload JSON 
    // or include recordId in the SyncOperationModel.
    try {
      // Simulate checking timestamp for First-Write-Wins
      // Let's assume operation.createdAt is the timestamp we check
      // For testing, we randomly succeed.
      return SyncResult(success: true);
    } catch (e) {
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }
}
