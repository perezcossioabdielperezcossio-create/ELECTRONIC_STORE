import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../models/promoter_model.dart';

abstract class PromoterLocalDatasource {
  Future<List<PromoterModel>> getAllPromoters();
  Future<PromoterModel>       getPromoterById(String id);
  Future<void>                savePromoter(PromoterModel model);
}

class PromoterLocalDatasourceImpl implements PromoterLocalDatasource {
  final DatabaseHelper dbHelper;
  const PromoterLocalDatasourceImpl(this.dbHelper);

  @override
  Future<List<PromoterModel>> getAllPromoters() async {
    final db   = await dbHelper.database;
    final maps = await db.query('promoters', where: 'is_active = 1');
    return maps.map(PromoterModel.fromMap).toList();
  }

  @override
  Future<PromoterModel> getPromoterById(String id) async {
    final db   = await dbHelper.database;
    final maps = await db.query('promoters', where: 'id = ?', whereArgs: [id]);
    return PromoterModel.fromMap(maps.first);
  }

  @override
  Future<void> savePromoter(PromoterModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('promoters', model.toMap());
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'promoters',
        'operation': 'CREATE',
        'payload': jsonEncode(model.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }
}
