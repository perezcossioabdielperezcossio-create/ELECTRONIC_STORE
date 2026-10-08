import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> initTable();
  Future<void> seedMasterAdmins();
  Future<UserModel?> getUserByPhone(String celular);
  Future<void> saveUser(UserModel user);
  Future<List<UserModel>> getAllUsers();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final DatabaseHelper dbHelper;

  AuthLocalDataSourceImpl({required this.dbHelper});

  Future<Database> get _db => dbHelper.database;

  @override
  Future<void> initTable() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        celular TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL,
        tienda_nombre TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
      );
    ''');
  }

  @override
  Future<void> seedMasterAdmins() async {
    final db = await _db;
    await initTable();

    for (final admin in UserModel.masterAdmins) {
      final existing = await db.query(
        'users',
        where: 'celular = ?',
        whereArgs: [admin.celular],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert(
          'users',
          admin.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Ensure role, pin and active status are up to date for master admins
        await db.update(
          'users',
          admin.toMap(),
          where: 'celular = ?',
          whereArgs: [admin.celular],
        );
      }
    }
  }

  @override
  Future<UserModel?> getUserByPhone(String celular) async {
    final db = await _db;
    await initTable();
    final cleanPhone = celular.trim();

    final results = await db.query(
      'users',
      where: 'celular = ?',
      whereArgs: [cleanPhone],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final db = await _db;
    await initTable();

    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final db = await _db;
    await initTable();

    final results = await db.query('users', orderBy: 'nombre ASC');
    return results.map((m) => UserModel.fromMap(m)).toList();
  }
}
