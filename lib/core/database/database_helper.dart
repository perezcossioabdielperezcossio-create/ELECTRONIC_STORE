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
    await _ensureLotsLocationColumn(db);
    await _ensureVentasColumns(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMissingTables(db);
    }
    await _ensureLotsLocationColumn(db);
    await _ensureVentasColumns(db);
  }

  Future<void> _ensureLotsLocationColumn(DatabaseExecutor db) async {
    try {
      await db.execute("ALTER TABLE lots ADD COLUMN location TEXT NOT NULL DEFAULT 'ALMACEN';");
    } catch (_) {}
  }

  Future<void> _ensureVentasColumns(DatabaseExecutor db) async {
    try {
      await db.execute("ALTER TABLE ventas ADD COLUMN usuario_id TEXT;");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE ventas ADD COLUMN origen_venta TEXT DEFAULT 'ALMACEN';");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE ventas ADD COLUMN store_location TEXT DEFAULT 'ALMACEN';");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN usuario_id TEXT;");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN origen_venta TEXT DEFAULT 'ALMACEN';");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN store_location TEXT DEFAULT 'ALMACEN';");
    } catch (_) {}
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas_vendedor (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        vendedor_nombre TEXT,
        cliente_nombre TEXT,
        fecha_venta TEXT NOT NULL,
        total_cobrado REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        status TEXT DEFAULT 'COMPLETED',
        is_locked INTEGER DEFAULT 1,
        items TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      );
    ''');
  }
}
