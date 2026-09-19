import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/promoter_model.dart';
import '../models/reservation_model.dart';

abstract class PromoterLocalDatasource {
  Future<List<PromoterModel>> getAllPromoters();
  Future<PromoterModel>       getPromoterById(String id);
  Future<void>                savePromoter(PromoterModel model);
  
  Future<void>                createReservation(ReservationModel model);
  Future<List<ReservationModel>> getReservationsByPromoter(String promoterId);
  Future<void>                checkAndExpireReservations();
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
    await db.insert('promoters', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> createReservation(ReservationModel model) async {
    final db = await dbHelper.database;
    await db.insert('reservations', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ReservationModel>> getReservationsByPromoter(String promoterId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'reservations', 
      where: 'promoter_id = ?', 
      whereArgs: [promoterId],
      orderBy: 'created_at DESC',
    );
    return maps.map(ReservationModel.fromMap).toList();
  }

  @override
  Future<void> checkAndExpireReservations() async {
    final db = await dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    
    await db.update(
      'reservations',
      {'status': 'EXPIRED'},
      where: 'status = ? AND expires_at < ?',
      whereArgs: ['ACTIVE', nowIso],
    );
  }
}
