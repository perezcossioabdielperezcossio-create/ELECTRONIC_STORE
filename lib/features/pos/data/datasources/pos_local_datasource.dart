import '../../../../data/local/database_helper.dart';
import '../models/sale_model.dart';

abstract class PosLocalDatasource {
  Future<void>          saveSale(SaleModel model);
  Future<SaleModel>     getSaleById(String id);
  Future<List<SaleModel>> getSalesByDate(DateTime date);
  Future<void>          voidSale(String id);
}

class PosLocalDatasourceImpl implements PosLocalDatasource {
  final DatabaseHelper dbHelper;
  const PosLocalDatasourceImpl(this.dbHelper);

  @override
  Future<void> saveSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.insert('sales', model.toMap());
  }

  @override
  Future<SaleModel> getSaleById(String id) async {
    final db   = await dbHelper.database;
    final maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    return SaleModel.fromMap(maps.first);
  }

  @override
  Future<List<SaleModel>> getSalesByDate(DateTime date) async {
    final db    = await dbHelper.database;
    final start = DateTime(date.year, date.month, date.day);
    final end   = start.add(const Duration(days: 1));
    final maps  = await db.query(
      'sales',
      where:     'created_at >= ? AND created_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map((m) => SaleModel.fromMap(m)).toList();
  }

  @override
  Future<void> voidSale(String id) async {
    final db = await dbHelper.database;
    await db.update('sales', {'status': 'voided'},
        where: 'id = ?', whereArgs: [id]);
  }
}
