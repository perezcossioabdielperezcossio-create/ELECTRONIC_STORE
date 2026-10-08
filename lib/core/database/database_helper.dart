import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      final schemaStr = await rootBundle.loadString('assets/sql/schema.sql');
      final statements = schemaStr.split(';');

      await db.transaction((txn) async {
        for (final stmt in statements) {
          final sql = stmt.trim();
          if (sql.isNotEmpty) {
            await txn.execute(sql);
          }
        }
      });
    } catch (_) {}

    await _createMissingTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMissingTables(db);
    }
  }

  Future<void> _createMissingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id TEXT PRIMARY KEY,
        nombre_alias TEXT NOT NULL,
        telefono_whatsapp TEXT NOT NULL,
        direccion_predet TEXT,
        creado_en TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deliveries (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL,
        vehiculo TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        creado_en TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id TEXT PRIMARY KEY,
        celular TEXT UNIQUE NOT NULL,
        nombre TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL,
        tienda_nombre TEXT,
        activo INTEGER NOT NULL DEFAULT 1
      );
    ''');
  }
}
