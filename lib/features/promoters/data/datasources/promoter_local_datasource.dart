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
    await db.insert('promoters', model.toMap());
  }
}
