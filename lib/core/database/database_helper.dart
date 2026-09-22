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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}
}
