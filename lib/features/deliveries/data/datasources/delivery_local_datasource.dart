import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/delivery_model.dart';

abstract class DeliveryLocalDataSource {
  Future<List<DeliveryModel>> getDeliveries({bool onlyActive = false});
  Future<DeliveryModel?> getDeliveryById(String id);
  Future<void> insertOrUpdateDelivery(DeliveryModel delivery);
  Future<void> saveDelivery(DeliveryModel delivery);
  Future<void> deleteDelivery(String id);
}

class DeliveryLocalDataSourceImpl implements DeliveryLocalDataSource {
  final DatabaseHelper dbHelper;

  DeliveryLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<DeliveryModel>> getDeliveries({bool onlyActive = false}) async {
    final db = await dbHelper.database;
    try {
      final results = await db.query(
        'deliveries',
        where: onlyActive ? 'activo = 1' : null,
        orderBy: 'nombre ASC',
      );
      return results.map((m) => DeliveryModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<DeliveryModel?> getDeliveryById(String id) async {
    final db = await dbHelper.database;
    try {
      final results = await db.query('deliveries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (results.isNotEmpty) {
        return DeliveryModel.fromMap(results.first);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> insertOrUpdateDelivery(DeliveryModel delivery) async {
    final db = await dbHelper.database;
    await db.insert(
      'deliveries',
      delivery.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveDelivery(DeliveryModel delivery) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'deliveries',
        delivery.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'deliveries',
        'operation': 'CREATE',
        'payload': jsonEncode(delivery.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> deleteDelivery(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('deliveries', where: 'id = ?', whereArgs: [id]);

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'deliveries',
        'operation': 'DELETE',
        'payload': jsonEncode({'id': id}),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }
}
