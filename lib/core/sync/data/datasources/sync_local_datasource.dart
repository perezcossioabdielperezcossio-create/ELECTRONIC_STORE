import '../../../../core/database/database_helper.dart';
import '../models/sync_operation_model.dart';

abstract class SyncLocalDataSource {
  Future<void> enqueue(SyncOperationModel operation);
  Future<List<SyncOperationModel>> getPendingOperations();
  Future<void> markAsSynced(String id);
  Future<void> markAsFailed(String id, String error);
}

class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final DatabaseHelper dbHelper;

  SyncLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<void> enqueue(SyncOperationModel operation) async {
    final db = await dbHelper.database;
    await db.insert('sync_queue', operation.toMap());
  }

  @override
  Future<List<SyncOperationModel>> getPendingOperations() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'sync_queue',
      where: "status = 'PENDING' OR status = 'FAILED'",
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => SyncOperationModel.fromMap(map)).toList();
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'sync_queue',
      {'status': 'SYNCED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAsFailed(String id, String error) async {
    final db = await dbHelper.database;
    
    // Get current retry count
    final result = await db.query('sync_queue', columns: ['retry_count'], where: 'id = ?', whereArgs: [id]);
    int currentRetryCount = 0;
    if (result.isNotEmpty) {
      currentRetryCount = (result.first['retry_count'] as int?) ?? 0;
    }
    
    await db.update(
      'sync_queue',
      {
        'status': 'FAILED',
        'retry_count': currentRetryCount + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
