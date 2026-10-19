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
  Stream<List<Map<String, dynamic>>> listenToRemoteProducts();
  Stream<List<Map<String, dynamic>>> listenToRemoteLots({String? location});
  Stream<List<Map<String, dynamic>>> listenToRemoteSales();
  Stream<List<Map<String, dynamic>>> listenToRemoteClients();
  Stream<List<Map<String, dynamic>>> listenToRemoteDeliveries();
  Stream<List<Map<String, dynamic>>> listenToRemoteUsers();
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges();
  Stream<List<Map<String, dynamic>>> listenToSellerSales(String sellerPhone);
  Future<List<Map<String, dynamic>>> fetchSellerSales({String? sellerPhone});
}

class MockRemoteSyncDataSource implements RemoteSyncDataSource {
  bool shouldSucceed = true;

  @override
  Future<SyncResult> syncOperation(SyncOperationModel operation) async {
    if (!shouldSucceed) {
      return SyncResult(success: false, errorMessage: 'Mock failure');
    }
    return SyncResult(success: true);
  }

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteProducts() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteLots({String? location}) => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteSales() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteClients() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteDeliveries() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteUsers() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToSellerSales(String sellerPhone) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchSellerSales({String? sellerPhone}) async => [];
}
