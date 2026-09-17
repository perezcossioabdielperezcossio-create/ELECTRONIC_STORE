import '../../../../data/local/database_helper.dart';
import '../models/sale_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class PosLocalDatasource {
  Future<void>          saveSale(SaleModel model);
  Future<void>          processSale(SaleModel model);
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
  Future<void> processSale(SaleModel model) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('sales', model.toMap());
      
      for (final item in model.items) {
        await txn.insert('sale_items', {
          'sale_id': model.id,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'line_discount': item.lineDiscount,
        });

        int remainingQuantity = item.quantity;
        final netUnitPrice = item.quantity > 0 ? (item.unitPrice - (item.lineDiscount / item.quantity)) : 0.0;

        final lotsMaps = await txn.query(
          'lots',
          where: 'product_id = ? AND current_quantity > 0',
          whereArgs: [item.productId],
          orderBy: 'purchase_date ASC',
        );

        for (final lot in lotsMaps) {
          if (remainingQuantity <= 0) break;

          final lotId = lot['id'] as String;
          final currentQuantity = lot['current_quantity'] as int;
          final realUnitCost = (lot['real_unit_cost'] as num).toDouble();

          if (netUnitPrice < realUnitCost) {
            throw AntiLossException('La venta del producto ${item.productName} generaría pérdida frente al costo del lote.');
          }

          final qtyToConsume = remainingQuantity <= currentQuantity ? remainingQuantity : currentQuantity;
          
          await txn.update(
            'lots',
            {'current_quantity': currentQuantity - qtyToConsume},
            where: 'id = ?',
            whereArgs: [lotId],
          );

          remainingQuantity -= qtyToConsume;
        }

        if (remainingQuantity > 0) {
          throw InsufficientStockException('Stock insuficiente para el producto ${item.productName}.');
        }
      }
    });
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
