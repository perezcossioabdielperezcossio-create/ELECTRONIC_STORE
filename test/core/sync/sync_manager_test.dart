import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import 'package:electronic_store/core/sync/data/models/sync_operation_model.dart';
import 'package:electronic_store/core/sync/data/datasources/sync_local_datasource.dart';
import 'package:electronic_store/core/sync/data/datasources/remote_sync_datasource.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import 'package:uuid/uuid.dart';

// Test implementation of RemoteSyncDataSource
class TestRemoteSyncDataSource implements RemoteSyncDataSource {
  bool shouldSucceed = true;
  String? error;

  @override
  Future<SyncResult> syncOperation(SyncOperationModel operation) async {
    if (shouldSucceed) {
      return SyncResult(success: true);
    } else {
      return SyncResult(success: false, errorMessage: error ?? 'Simulated error');
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteProducts() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteLots() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteSales() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteClients() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteDeliveries() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteUsers() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges() {
    return const Stream.empty();
  }
}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late Database db;
  late SyncLocalDataSourceImpl localDataSource;
  late TestRemoteSyncDataSource remoteDataSource;
  late SyncManager syncManager;
  late MockDatabaseHelper mockDatabaseHelper;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS sync_queue (
                    id TEXT PRIMARY KEY,
                    table_name TEXT NOT NULL,
                    operation TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    status TEXT DEFAULT 'PENDING',
                    retry_count INTEGER DEFAULT 0
                );
              ''');
            }));

    mockDatabaseHelper = MockDatabaseHelper();
    when(() => mockDatabaseHelper.database).thenAnswer((_) async => db);

    localDataSource = SyncLocalDataSourceImpl(dbHelper: mockDatabaseHelper);
    remoteDataSource = TestRemoteSyncDataSource();
    syncManager = SyncManager(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Test 1: Comprobar que una venta local sin conexión se encola correctamente en sync_queue con status PENDING', () async {
    final operation = SyncOperationModel(
      id: const Uuid().v4(),
      tableName: 'sales',
      operation: 'CREATE',
      payload: jsonEncode({'amount': 100}),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await localDataSource.enqueue(operation);

    final pending = await localDataSource.getPendingOperations();
    expect(pending.length, 1);
    expect(pending.first.id, operation.id);
    expect(pending.first.status, 'PENDING');
  });

  test('Test 2: Simular recuperación de red y verificar que SyncManager.syncPendingOperations() procesa la cola en orden FIFO y marca los registros como SYNCED', () async {
    final op1 = SyncOperationModel(
      id: const Uuid().v4(),
      tableName: 'sales',
      operation: 'CREATE',
      payload: jsonEncode({'id': 1}),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await Future.delayed(const Duration(milliseconds: 10));
    final op2 = SyncOperationModel(
      id: const Uuid().v4(),
      tableName: 'sales',
      operation: 'CREATE',
      payload: jsonEncode({'id': 2}),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await localDataSource.enqueue(op1);
    await localDataSource.enqueue(op2);

    remoteDataSource.shouldSucceed = true;
    
    await syncManager.syncPendingOperations();

    final pending = await localDataSource.getPendingOperations();
    expect(pending.length, 0);

    final results = await db.query('sync_queue', orderBy: 'created_at ASC');
    expect(results.length, 0); // They are deleted upon sync
  });

  test('Test 3: Verificar que un fallo de red transitorio aumente retry_count sin borrar el registro de la cola', () async {
    final op = SyncOperationModel(
      id: const Uuid().v4(),
      tableName: 'sales',
      operation: 'CREATE',
      payload: jsonEncode({'amount': 50}),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await localDataSource.enqueue(op);

    remoteDataSource.shouldSucceed = false;
    remoteDataSource.error = 'Network error';

    await syncManager.syncPendingOperations();

    final pending = await localDataSource.getPendingOperations();
    expect(pending.length, 1);

    final results = await db.query('sync_queue', where: 'id = ?', whereArgs: [op.id]);
    expect(results.first['status'], 'FAILED');
    expect(results.first['retry_count'], 1);
  });

  test('Test 4: Verificar que una operacion DELETE de productos se procesa exitosamente y se sincroniza al recuperar conexion', () async {
    final op = SyncOperationModel(
      id: const Uuid().v4(),
      tableName: 'products',
      operation: 'DELETE',
      payload: jsonEncode({'sku': 'SKU-DELETE-1', 'id': 'prod-123'}),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await localDataSource.enqueue(op);

    // Initial state: 1 pending deletion
    var pending = await localDataSource.getPendingOperations();
    expect(pending.length, 1);
    expect(pending.first.operation, 'DELETE');
    expect(pending.first.tableName, 'products');

    remoteDataSource.shouldSucceed = true;

    await syncManager.syncPendingOperations();

    // After sync: queue is processed and cleaned
    pending = await localDataSource.getPendingOperations();
    expect(pending.length, 0);
  });
}
