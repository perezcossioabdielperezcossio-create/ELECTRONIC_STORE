import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'remote_sync_datasource.dart';
import '../models/sync_operation_model.dart';
import '../../../../features/inventory/data/models/product_model.dart';
import '../../../../features/inventory/data/models/lot_model.dart';
import '../../../../features/pos/data/models/sale_model.dart';

class FirestoreRemoteDataSource implements RemoteSyncDataSource {
  final FirebaseFirestore firestore;

  FirestoreRemoteDataSource({required this.firestore});

  @override
  Future<SyncResult> syncOperation(SyncOperationModel operation) async {
    try {
      final payloadMap = jsonDecode(operation.payload) as Map<String, dynamic>;
      // Add clientTimestamp for First-Write-Wins (RNF-03)
      payloadMap['clientTimestamp'] = operation.createdAt;
      payloadMap['lastModified'] = operation.createdAt; // Use creation time as last modification timestamp for sync

      if (operation.tableName == 'products' || operation.tableName == 'productos') {
        if (operation.operation == 'DELETE') {
          final sku = (payloadMap['sku'] as String?) ?? (payloadMap['id'] as String);
          await deleteProduct(sku);
        } else {
          final product = ProductModel.fromMap(payloadMap);
          await pushProduct(product, operation.operation);
        }
      } else if (operation.tableName == 'lots' || operation.tableName == 'lotes') {
        if (operation.operation == 'DELETE') {
          final lotId = (payloadMap['id'] as String?) ?? operation.id;
          await firestore.collection('lots').doc(lotId).delete();
        } else if (operation.operation == 'UPDATE') {
          final lotId = (payloadMap['id'] as String?) ?? operation.id;
          await firestore.collection('lots').doc(lotId).set(payloadMap, SetOptions(merge: true));
        } else {
          final lot = LotModel.fromMap(payloadMap);
          await pushLot(lot, operation.operation, payloadMap);
        }
      } else if (operation.tableName == 'sales' || operation.tableName == 'ventas') {
        if (operation.operation == 'DELETE') {
          final saleId = (payloadMap['id'] as String?) ?? operation.id;
          await firestore.collection('sales').doc(saleId).delete();
        } else {
          final sale = SaleModel.fromMap(payloadMap);
          await pushSale(sale, operation.operation, payloadMap);
        }
      } else {
        return SyncResult(success: false, errorMessage: 'Unknown table: ${operation.tableName}');
      }

      return SyncResult(success: true);
    } catch (e) {
      debugPrint('Firestore sync error: $e');
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteProduct(String sku) async {
    // Eliminar el documento en la colección 'products'
    await firestore.collection('products').doc(sku).delete();
    
    // Eliminar los lotes asociados en la colección 'lots'
    final lotsQuery = await firestore.collection('lots').where('productSku', isEqualTo: sku).get();
    final batch = firestore.batch();
    for (var doc in lotsQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> pushProduct(ProductModel product, String operationType) async {
    final docRef = firestore.collection('products').doc(product.sku); // ID = sku
    if (operationType == 'DELETE') {
      await deleteProduct(product.sku);
    } else {
      await docRef.set(product.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> pushLot(LotModel lot, String operationType, [Map<String, dynamic>? fullPayload]) async {
    final docRef = firestore.collection('lots').doc(lot.id);
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      final mapToSet = fullPayload != null ? Map<String, dynamic>.from(fullPayload) : lot.toMap();
      mapToSet['id'] = lot.id;
      mapToSet['product_id'] = lot.productId;
      mapToSet['productSku'] = mapToSet['productSku'] ?? lot.productId;
      mapToSet['costo_unitario_real'] = lot.realUnitCost;
      mapToSet['real_unit_cost'] = lot.realUnitCost;
      mapToSet['cantidad_actual'] = lot.currentQuantity;
      mapToSet['current_quantity'] = lot.currentQuantity;
      mapToSet['cantidad_inicial'] = lot.initialQuantity;
      mapToSet['initial_quantity'] = lot.initialQuantity;
      mapToSet['fecha_ingreso'] = lot.purchaseDate.toIso8601String();
      mapToSet['purchase_date'] = lot.purchaseDate.toIso8601String();
      if (lot.promoterBasePrice != null) {
        mapToSet['promoter_base_price'] = lot.promoterBasePrice;
        mapToSet['promoterBasePrice'] = lot.promoterBasePrice;
      }
      mapToSet['is_active'] = lot.isActive ? 1 : 0;
      await docRef.set(mapToSet, SetOptions(merge: true));
    }
  }

  Future<void> pushSale(SaleModel sale, String operationType, [Map<String, dynamic>? fullPayload]) async {
    final docRef = firestore.collection('sales').doc(sale.id);
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      final mapToSet = fullPayload ?? sale.toMap();
      await docRef.set(mapToSet, SetOptions(merge: true));
    }
  }

  /// Listen to remote changes for Products
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteProducts() {
    return firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
  }

  /// Listen to remote changes for Lots
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteLots() {
    return firestore.collection('lots').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
  }

  /// Listen to remote changes for Sales
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteSales() {
    return firestore.collection('sales').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
  }

  /// Listen to remote changes for Reactive UI/Real-time Updates (RNF-02)
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges() {
    return listenToRemoteProducts();
  }
}
