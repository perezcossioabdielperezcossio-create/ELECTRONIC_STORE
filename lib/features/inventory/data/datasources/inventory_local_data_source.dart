import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/lot_model.dart';
import '../models/product_model.dart';
import 'inventory_remote_data_source.dart';

abstract class InventoryLocalDataSource {
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot);
  Future<void> addLotToProduct(String productId, LotModel lot);
  Future<ProductModel?> getProductBySku(String sku);
  Future<List<ProductModel>> getActiveInventory();

  Future<void> updateProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<void> deleteLot(String lotId);
  Future<List<LotModel>> consumeStock(String productId, int quantity, {String? location});
  Future<List<ProductModel>> getAllProducts();
  Future<void> transferStockToStore({
    required String productId,
    required int quantity,
    String? sellerId,
    String? storeLocation,
    double? unitPrice,
  });
  Future<void> revertOrAdjustStoreStock({
    String? lotId,
    String? productId,
    int? newQuantity,
  });
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  final Database database;
  final FirebaseFirestore? firestore;
  final InventoryRemoteDataSource? inventoryRemoteDataSource;

  InventoryLocalDataSourceImpl(
    this.database, {
    this.firestore,
    this.inventoryRemoteDataSource,
  });

  InventoryRemoteDataSource? get _effectiveRemoteDataSource {
    if (inventoryRemoteDataSource != null) return inventoryRemoteDataSource;
    if (firestore != null) {
      return FirestoreInventoryRemoteDataSource(firestore: firestore!);
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirestoreInventoryRemoteDataSource(firestore: FirebaseFirestore.instance);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveProductWithInitialLot(ProductModel product, LotModel initialLot) async {
    await database.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'operation': 'CREATE',
        'payload': jsonEncode(product.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });

      final lotPayload = {
        'id': initialLot.id,
        'product_id': product.id,
        'productSku': product.sku,
        'productId': product.id,
        'costo_unitario_real': initialLot.realUnitCost,
        'real_unit_cost': initialLot.realUnitCost,
        'cantidad_actual': initialLot.currentQuantity,
        'current_quantity': initialLot.currentQuantity,
        'cantidad_inicial': initialLot.initialQuantity,
        'initial_quantity': initialLot.initialQuantity,
        'fecha_ingreso': initialLot.purchaseDate.toIso8601String(),
        'purchase_date': initialLot.purchaseDate.toIso8601String(),
        'location': initialLot.location,
        'ubicacion': initialLot.location,
        if (initialLot.promoterBasePrice != null) 'promoter_base_price': initialLot.promoterBasePrice,
        if (initialLot.promoterBasePrice != null) 'promoterBasePrice': initialLot.promoterBasePrice,
        'is_active': initialLot.isActive ? 1 : 0,
      };

      await txn.insert(
        'lots',
        initialLot.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'CREATE',
        'payload': jsonEncode(lotPayload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> addLotToProduct(String productId, LotModel lot) async {
    await database.transaction((txn) async {
      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;

      final lotPayload = {
        'id': lot.id,
        'product_id': productId,
        'productSku': sku,
        'productId': productId,
        'costo_unitario_real': lot.realUnitCost,
        'real_unit_cost': lot.realUnitCost,
        'cantidad_actual': lot.currentQuantity,
        'current_quantity': lot.currentQuantity,
        'cantidad_inicial': lot.initialQuantity,
        'initial_quantity': lot.initialQuantity,
        'fecha_ingreso': lot.purchaseDate.toIso8601String(),
        'purchase_date': lot.purchaseDate.toIso8601String(),
        'location': lot.location,
        'ubicacion': lot.location,
        if (lot.promoterBasePrice != null) 'promoter_base_price': lot.promoterBasePrice,
        if (lot.promoterBasePrice != null) 'promoterBasePrice': lot.promoterBasePrice,
        'is_active': lot.isActive ? 1 : 0,
      };

      await txn.insert(
        'lots',
        lot.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'CREATE',
        'payload': jsonEncode(lotPayload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<ProductModel?> getProductBySku(String sku) async {
    final result = await database.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final productMap = result.first;
    final productId = productMap['id'] as String;

    final lotsResult = await database.query(
      'lots',
      where: 'product_id = ? AND current_quantity > 0 AND is_active = 1',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC',
    );

    final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();

    return ProductModel.fromMap(productMap, lots: lots);
  }

  @override
  Future<List<ProductModel>> getActiveInventory() async {
    final productsResult = await database.query('products', where: 'is_active = 1');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0 AND is_active = 1',
        whereArgs: [productId],
        orderBy: 'purchase_date ASC',
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots: lots));
    }
    
    return inventory;
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    final productsResult = await database.query('products', where: 'is_active = 1');
    final List<ProductModel> inventory = [];

    for (final productMap in productsResult) {
      final productId = productMap['id'] as String;
      
      final lotsResult = await database.query(
        'lots',
        where: 'product_id = ? AND current_quantity > 0 AND is_active = 1',
        whereArgs: [productId],
        orderBy: 'purchase_date ASC',
      );
      
      final lots = lotsResult.map((lotMap) => LotModel.fromMap(lotMap)).toList();
      inventory.add(ProductModel.fromMap(productMap, lots: lots));
    }
    
    return inventory;
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    await database.transaction((txn) async {
      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'products',
        'operation': 'UPDATE',
        'payload': jsonEncode(product.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    });
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await database.transaction((txn) async {
      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;

      // Verificar si tiene ventas asociadas para borrado físico vs lógico
      int salesCount = 0;
      try {
        final salesCountResult = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM detalle_ventas WHERE product_id = ?',
          [productId],
        );
        salesCount = Sqflite.firstIntValue(salesCountResult) ?? 0;
      } catch (_) {
        salesCount = 0;
      }

      if (salesCount == 0) {
        // Borrado físico si NO tiene ventas
        final lots = await txn.query('lots', where: 'product_id = ?', whereArgs: [productId]);
        for (final lot in lots) {
          await txn.insert('sync_queue', {
            'id': const Uuid().v4(),
            'table_name': 'lots',
            'operation': 'DELETE',
            'payload': jsonEncode({'id': lot['id'], 'productSku': sku}),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'PENDING',
            'retry_count': 0,
          });
        }
        await txn.delete('lots', where: 'product_id = ?', whereArgs: [productId]);
        await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
        
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'products',
          'operation': 'DELETE',
          'payload': jsonEncode({'id': productId, 'sku': sku}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });
      } else {
        // Borrado lógico (is_active = 0) si TIENE ventas
        await txn.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [productId]);
        await txn.update('lots', {'is_active': 0, 'current_quantity': 0}, where: 'product_id = ?', whereArgs: [productId]);

        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'products',
          'operation': 'UPDATE',
          'payload': jsonEncode({'id': productId, 'sku': sku, 'is_active': 0}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });

        final lots = await txn.query('lots', where: 'product_id = ?', whereArgs: [productId]);
        for (final lot in lots) {
          await txn.insert('sync_queue', {
            'id': const Uuid().v4(),
            'table_name': 'lots',
            'operation': 'UPDATE',
            'payload': jsonEncode({'id': lot['id'], 'is_active': 0, 'current_quantity': 0}),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'PENDING',
            'retry_count': 0,
          });
        }
      }
    });
  }

  @override
  Future<void> deleteLot(String lotId) async {
    await database.transaction((txn) async {
      final lotQuery = await txn.query('lots', where: 'id = ?', whereArgs: [lotId], limit: 1);
      if (lotQuery.isEmpty) return;
      final productId = lotQuery.first['product_id'] as String;
      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;

      int salesCount = 0;
      try {
        final salesCountResult = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM detalle_ventas WHERE lote_id = ?',
          [lotId],
        );
        salesCount = Sqflite.firstIntValue(salesCountResult) ?? 0;
      } catch (_) {
        salesCount = 0;
      }

      if (salesCount == 0) {
        // Borrado físico si no tiene ventas
        await txn.delete('lots', where: 'id = ?', whereArgs: [lotId]);
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'DELETE',
          'payload': jsonEncode({'id': lotId, 'productSku': sku}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });
      } else {
        // Borrado lógico si tiene ventas
        await txn.update('lots', {'is_active': 0, 'current_quantity': 0}, where: 'id = ?', whereArgs: [lotId]);
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'UPDATE',
          'payload': jsonEncode({'id': lotId, 'is_active': 0, 'current_quantity': 0}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });
      }
    });
  }

  @override
  Future<List<LotModel>> consumeStock(String productId, int quantity, {String? location}) async {
    String whereClause = "product_id = ? AND current_quantity > 0 AND is_active = 1";
    final whereArgs = <dynamic>[productId];

    if (location != null && location.isNotEmpty) {
      final locUpper = location.toUpperCase().trim();
      if (locUpper == 'TIENDA') {
        whereClause += " AND UPPER(COALESCE(location, 'ALMACEN')) = 'TIENDA'";
      } else if (locUpper == 'ALMACEN') {
        whereClause += " AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'";
      }
    }

    final maps = await database.query(
      'lots',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'purchase_date ASC',
    );
    final lots = maps.map((m) => LotModel.fromMap(m)).toList();
    final consumed = <LotModel>[];
    var remaining = quantity;

    await database.transaction((txn) async {
      for (final lot in lots) {
        if (remaining <= 0) break;
        final take = lot.currentQuantity < remaining ? lot.currentQuantity : remaining;
        final newQuantity = lot.currentQuantity - take;
        
        await txn.update(
          'lots',
          {'current_quantity': newQuantity},
          where: 'id = ?', whereArgs: [lot.id],
        );
        
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'UPDATE',
          'payload': jsonEncode({'id': lot.id, 'current_quantity': newQuantity}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });

        consumed.add(lot);
        remaining -= take;
      }
    });

    if (remaining > 0) throw Exception('Stock insuficiente');
    return consumed;
  }

  @override
  Future<void> transferStockToStore({
    required String productId,
    required int quantity,
    String? sellerId,
    String? storeLocation,
    double? unitPrice,
  }) async {
    if (quantity <= 0) {
      throw Exception('La cantidad a transferir debe ser mayor a 0');
    }

    final locationDestino = (storeLocation != null && storeLocation.isNotEmpty)
        ? storeLocation.toUpperCase().trim()
        : 'TIENDA';

    final remoteOps = <_LotTransferRemoteOp>[];

    await database.transaction((txn) async {
      final maps = await txn.query(
        'lots',
        where: "product_id = ? AND current_quantity > 0 AND is_active = 1 AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'",
        whereArgs: [productId],
        orderBy: 'purchase_date ASC',
      );

      final warehouseLots = maps.map((m) => LotModel.fromMap(m)).toList();
      final totalWarehouseStock = warehouseLots.fold<int>(0, (totalStock, l) => totalStock + l.currentQuantity);

      if (totalWarehouseStock < quantity) {
        throw Exception('Stock insuficiente en Almacén Central (Disponible: $totalWarehouseStock, Requerido: $quantity)');
      }

      final prodQuery = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      final sku = prodQuery.isNotEmpty ? (prodQuery.first['sku'] as String) : productId;
      final prodStandardPrice = prodQuery.isNotEmpty ? ((prodQuery.first['standard_selling_price'] as num?)?.toDouble() ?? 0.0) : 0.0;

      var remaining = quantity;
      for (final lot in warehouseLots) {
        if (remaining <= 0) break;
        final take = lot.currentQuantity < remaining ? lot.currentQuantity : remaining;
        final newAlmQty = lot.currentQuantity - take;
        final nowIso = DateTime.now().toIso8601String();

        await txn.update(
          'lots',
          {'current_quantity': newAlmQty, 'is_active': newAlmQty > 0 ? 1 : 0},
          where: 'id = ?',
          whereArgs: [lot.id],
        );

        final almacenUpdatePayload = {
          'id': lot.id,
          'current_quantity': newAlmQty,
          'current_qty': newAlmQty,
          'is_active': newAlmQty > 0 ? 1 : 0,
          'updated_at': nowIso,
        };

        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'UPDATE',
          'payload': jsonEncode(almacenUpdatePayload),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });

        final tiendaLotId = const Uuid().v4();
        final costoCompraMayorista = lot.realUnitCost;
        final precioVentaAsignado = unitPrice ?? lot.promoterBasePrice ?? prodStandardPrice;

        final storeLot = LotModel(
          id: tiendaLotId,
          productId: productId,
          purchaseDate: DateTime.now().toUtc(),
          initialQuantity: take,
          currentQuantity: take,
          realUnitCost: costoCompraMayorista,
          promoterBasePrice: precioVentaAsignado,
          location: locationDestino,
        );

        final tiendaLotPayload = {
          "id": tiendaLotId,
          "product_id": productId,
          "location": locationDestino,
          "current_qty": take,
          "unit_cost": costoCompraMayorista,
          "unit_price": precioVentaAsignado,
          "updated_at": nowIso,
          "productSku": sku,
          "productId": productId,
          "current_quantity": take,
          "initial_quantity": take,
          "real_unit_cost": costoCompraMayorista,
          "costo_unitario_real": costoCompraMayorista,
          "promoter_base_price": precioVentaAsignado,
          "promoterBasePrice": precioVentaAsignado,
          "purchase_date": nowIso,
          "is_active": 1,
        };

        await txn.insert(
          'lots',
          storeLot.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'table_name': 'lots',
          'operation': 'CREATE',
          'payload': jsonEncode(tiendaLotPayload),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'PENDING',
          'retry_count': 0,
        });

        remoteOps.add(_LotTransferRemoteOp(
          almacenLotId: lot.id,
          almacenNewQty: newAlmQty,
          tiendaLotPayload: tiendaLotPayload,
        ));

        remaining -= take;
      }
    });

    final remoteDs = _effectiveRemoteDataSource;
    if (remoteDs != null) {
      for (final op in remoteOps) {
        try {
          await remoteDs.updateWarehouseLotStock(
            lotId: op.almacenLotId,
            newQuantity: op.almacenNewQty,
          );
        } catch (e) {
          debugPrint('Immediate Firestore update for warehouse lot ${op.almacenLotId} deferred to sync_queue: $e');
        }

        try {
          await remoteDs.createOrUpdateStoreLot(op.tiendaLotPayload);
        } catch (e) {
          debugPrint('Immediate Firestore create for store lot ${op.tiendaLotPayload['id']} deferred to sync_queue: $e');
        }
      }
    }
  }

  @override
  Future<void> revertOrAdjustStoreStock({
    String? lotId,
    String? productId,
    int? newQuantity,
  }) async {
    await database.transaction((txn) async {
      if (lotId != null && lotId.isNotEmpty) {
        final lotQuery = await txn.query('lots', where: 'id = ?', whereArgs: [lotId], limit: 1);
        if (lotQuery.isEmpty) return;
        final tiendaLot = LotModel.fromMap(lotQuery.first);
        final prodId = tiendaLot.productId;

        if (newQuantity == null || newQuantity <= 0) {
          final returnQty = tiendaLot.currentQuantity;
          if (returnQty > 0) {
            await _returnStockToWarehouse(txn, prodId, returnQty, tiendaLot.realUnitCost);
          }
          await txn.delete('lots', where: 'id = ?', whereArgs: [lotId]);
          await txn.insert('sync_queue', {
            'id': const Uuid().v4(),
            'table_name': 'lots',
            'operation': 'DELETE',
            'payload': jsonEncode({'id': lotId}),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'PENDING',
            'retry_count': 0,
          });
        } else {
          final diff = tiendaLot.currentQuantity - newQuantity;
          if (diff > 0) {
            await _returnStockToWarehouse(txn, prodId, diff, tiendaLot.realUnitCost);
            await txn.update(
              'lots',
              {'current_quantity': newQuantity},
              where: 'id = ?',
              whereArgs: [lotId],
            );
            await txn.insert('sync_queue', {
              'id': const Uuid().v4(),
              'table_name': 'lots',
              'operation': 'UPDATE',
              'payload': jsonEncode({'id': lotId, 'current_quantity': newQuantity}),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'status': 'PENDING',
              'retry_count': 0,
            });
          } else if (diff < 0) {
            final extraNeeded = -diff;
            final almQuery = await txn.query(
              'lots',
              where: "product_id = ? AND current_quantity > 0 AND is_active = 1 AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'",
              whereArgs: [prodId],
              orderBy: 'purchase_date ASC',
            );
            final warehouseLots = almQuery.map((m) => LotModel.fromMap(m)).toList();
            final available = warehouseLots.fold<int>(0, (s, l) => s + l.currentQuantity);
            if (available < extraNeeded) {
              throw Exception('Stock insuficiente en Almacén para aumentar la asignación (Disponible: $available, Requerido: $extraNeeded)');
            }
            var rem = extraNeeded;
            for (final almLot in warehouseLots) {
              if (rem <= 0) break;
              final take = almLot.currentQuantity < rem ? almLot.currentQuantity : rem;
              final newAlm = almLot.currentQuantity - take;
              await txn.update('lots', {'current_quantity': newAlm}, where: 'id = ?', whereArgs: [almLot.id]);
              await txn.insert('sync_queue', {
                'id': const Uuid().v4(),
                'table_name': 'lots',
                'operation': 'UPDATE',
                'payload': jsonEncode({'id': almLot.id, 'current_quantity': newAlm}),
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'status': 'PENDING',
                'retry_count': 0,
              });
              rem -= take;
            }
            final newInit = tiendaLot.initialQuantity < newQuantity ? newQuantity : tiendaLot.initialQuantity;
            await txn.update(
              'lots',
              {'current_quantity': newQuantity, 'initial_quantity': newInit},
              where: 'id = ?',
              whereArgs: [lotId],
            );
            await txn.insert('sync_queue', {
              'id': const Uuid().v4(),
              'table_name': 'lots',
              'operation': 'UPDATE',
              'payload': jsonEncode({'id': lotId, 'current_quantity': newQuantity, 'initial_quantity': newInit}),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'status': 'PENDING',
              'retry_count': 0,
            });
          }
        }
      } else if (productId != null && productId.isNotEmpty) {
        final tiendaLotsQuery = await txn.query(
          'lots',
          where: "product_id = ? AND UPPER(COALESCE(location, 'ALMACEN')) = 'TIENDA' AND is_active = 1 AND current_quantity > 0",
          whereArgs: [productId],
          orderBy: 'purchase_date DESC',
        );
        final tiendaLots = tiendaLotsQuery.map((m) => LotModel.fromMap(m)).toList();
        final currentStoreTotal = tiendaLots.fold<int>(0, (s, l) => s + l.currentQuantity);

        if (newQuantity == null || newQuantity <= 0) {
          for (final tLot in tiendaLots) {
            if (tLot.currentQuantity > 0) {
              await _returnStockToWarehouse(txn, productId, tLot.currentQuantity, tLot.realUnitCost);
            }
            await txn.delete('lots', where: 'id = ?', whereArgs: [tLot.id]);
            await txn.insert('sync_queue', {
              'id': const Uuid().v4(),
              'table_name': 'lots',
              'operation': 'DELETE',
              'payload': jsonEncode({'id': tLot.id}),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'status': 'PENDING',
              'retry_count': 0,
            });
          }
        } else {
          final diff = currentStoreTotal - newQuantity;
          if (diff > 0) {
            var remReturn = diff;
            for (final tLot in tiendaLots) {
              if (remReturn <= 0) break;
              final take = tLot.currentQuantity < remReturn ? tLot.currentQuantity : remReturn;
              await _returnStockToWarehouse(txn, productId, take, tLot.realUnitCost);
              final updatedQty = tLot.currentQuantity - take;
              if (updatedQty == 0) {
                await txn.delete('lots', where: 'id = ?', whereArgs: [tLot.id]);
                await txn.insert('sync_queue', {
                  'id': const Uuid().v4(),
                  'table_name': 'lots',
                  'operation': 'DELETE',
                  'payload': jsonEncode({'id': tLot.id}),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'status': 'PENDING',
                  'retry_count': 0,
                });
              } else {
                await txn.update('lots', {'current_quantity': updatedQty}, where: 'id = ?', whereArgs: [tLot.id]);
                await txn.insert('sync_queue', {
                  'id': const Uuid().v4(),
                  'table_name': 'lots',
                  'operation': 'UPDATE',
                  'payload': jsonEncode({'id': tLot.id, 'current_quantity': updatedQty}),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'status': 'PENDING',
                  'retry_count': 0,
                });
              }
              remReturn -= take;
            }
          } else if (diff < 0) {
            final extra = -diff;
            final almQuery = await txn.query(
              'lots',
              where: "product_id = ? AND current_quantity > 0 AND is_active = 1 AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'",
              whereArgs: [productId],
              orderBy: 'purchase_date ASC',
            );
            final warehouseLots = almQuery.map((m) => LotModel.fromMap(m)).toList();
            final available = warehouseLots.fold<int>(0, (s, l) => s + l.currentQuantity);
            if (available < extra) {
              throw Exception('Stock insuficiente en Almacén (Disponible: $available, Requerido: $extra)');
            }
            var rem = extra;
            for (final almLot in warehouseLots) {
              if (rem <= 0) break;
              final take = almLot.currentQuantity < rem ? almLot.currentQuantity : rem;
              final newAlm = almLot.currentQuantity - take;
              await txn.update('lots', {'current_quantity': newAlm}, where: 'id = ?', whereArgs: [almLot.id]);
              await txn.insert('sync_queue', {
                'id': const Uuid().v4(),
                'table_name': 'lots',
                'operation': 'UPDATE',
                'payload': jsonEncode({'id': almLot.id, 'current_quantity': newAlm}),
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'status': 'PENDING',
                'retry_count': 0,
              });
              final newStoreLot = LotModel(
                id: const Uuid().v4(),
                productId: productId,
                purchaseDate: DateTime.now().toUtc(),
                initialQuantity: take,
                currentQuantity: take,
                realUnitCost: almLot.realUnitCost,
                promoterBasePrice: almLot.promoterBasePrice,
                location: 'TIENDA',
              );
              await txn.insert('lots', newStoreLot.toSqliteMap());
              await txn.insert('sync_queue', {
                'id': const Uuid().v4(),
                'table_name': 'lots',
                'operation': 'CREATE',
                'payload': jsonEncode(newStoreLot.toMap()),
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'status': 'PENDING',
                'retry_count': 0,
              });
              rem -= take;
            }
          }
        }
      }
    });
  }

  Future<void> _returnStockToWarehouse(DatabaseExecutor txn, String productId, int qtyToReturn, double realUnitCost) async {
    final almLotsQuery = await txn.query(
      'lots',
      where: "product_id = ? AND UPPER(COALESCE(location, 'ALMACEN')) = 'ALMACEN'",
      whereArgs: [productId],
      orderBy: 'purchase_date DESC',
      limit: 1,
    );

    if (almLotsQuery.isNotEmpty) {
      final almLot = LotModel.fromMap(almLotsQuery.first);
      final newQty = almLot.currentQuantity + qtyToReturn;
      final newInit = almLot.initialQuantity < newQty ? newQty : almLot.initialQuantity;

      await txn.update(
        'lots',
        {'current_quantity': newQty, 'initial_quantity': newInit, 'is_active': 1},
        where: 'id = ?',
        whereArgs: [almLot.id],
      );

      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'UPDATE',
        'payload': jsonEncode({'id': almLot.id, 'current_quantity': newQty, 'initial_quantity': newInit, 'is_active': 1}),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    } else {
      final newAlmLot = LotModel(
        id: const Uuid().v4(),
        productId: productId,
        purchaseDate: DateTime.now().toUtc(),
        initialQuantity: qtyToReturn,
        currentQuantity: qtyToReturn,
        realUnitCost: realUnitCost,
        location: 'ALMACEN',
      );
      await txn.insert('lots', newAlmLot.toSqliteMap());
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'table_name': 'lots',
        'operation': 'CREATE',
        'payload': jsonEncode(newAlmLot.toMap()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'PENDING',
        'retry_count': 0,
      });
    }
  }
}

class _LotTransferRemoteOp {
  final String almacenLotId;
  final int almacenNewQty;
  final Map<String, dynamic> tiendaLotPayload;

  _LotTransferRemoteOp({
    required this.almacenLotId,
    required this.almacenNewQty,
    required this.tiendaLotPayload,
  });
}


