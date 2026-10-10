import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/client_model.dart';

abstract class ClientLocalDataSource {
  Future<List<ClientModel>> getAllClients();
  Future<ClientModel?> getClientById(String id);
  Future<void> saveClient(ClientModel client);
  Future<void> insertOrUpdateClient(ClientModel client);
  Future<List<ClientModel>> searchClients(String query);
}

class ClientLocalDataSourceImpl implements ClientLocalDataSource {
  final DatabaseHelper dbHelper;

  ClientLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<ClientModel>> getAllClients() async {
    final db = await dbHelper.database;
    try {
      final results = await db.query('clientes', orderBy: 'creado_en DESC');
      if (results.isNotEmpty) {
        return results.map((m) => ClientModel.fromMap(m)).toList();
      }
    } catch (_) {}

    // Fallback to customers table if clientes was empty/migrating
    try {
      final results = await db.query('customers', orderBy: 'created_at DESC');
      return results.map((m) => ClientModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ClientModel?> getClientById(String id) async {
    final db = await dbHelper.database;
    try {
      final results = await db.query('clientes', where: 'id = ?', whereArgs: [id], limit: 1);
      if (results.isNotEmpty) {
        return ClientModel.fromMap(results.first);
      }
    } catch (_) {}

    try {
      final results = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
      if (results.isNotEmpty) {
        return ClientModel.fromMap(results.first);
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> saveClient(ClientModel client) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'clientes',
        client.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      try {
        await txn.insert(
          'customers',
          client.toSqliteCustomerMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'clients',
        'operation': 'CREATE',
        'payload': jsonEncode(client.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> insertOrUpdateClient(ClientModel client) async {
    final db = await dbHelper.database;
    await db.insert(
      'clientes',
      client.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      await db.insert(
        'customers',
        client.toSqliteCustomerMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<List<ClientModel>> searchClients(String query) async {
    if (query.isEmpty) return getAllClients();
    final db = await dbHelper.database;
    final cleanQuery = '%${query.toLowerCase()}%';
    try {
      final results = await db.query(
        'clientes',
        where: 'LOWER(nombre_alias) LIKE ? OR LOWER(telefono_whatsapp) LIKE ?',
        whereArgs: [cleanQuery, cleanQuery],
        orderBy: 'nombre_alias ASC',
      );
      if (results.isNotEmpty) {
        return results.map((m) => ClientModel.fromMap(m)).toList();
      }
    } catch (_) {}

    try {
      final results = await db.query(
        'customers',
        where: 'LOWER(name) LIKE ? OR LOWER(phone) LIKE ?',
        whereArgs: [cleanQuery, cleanQuery],
        orderBy: 'name ASC',
      );
      return results.map((m) => ClientModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }
}
