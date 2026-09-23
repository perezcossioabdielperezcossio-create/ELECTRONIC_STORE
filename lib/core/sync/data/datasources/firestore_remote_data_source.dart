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

      if (operation.tableName == 'products') {
        final product = ProductModel.fromMap(payloadMap);
        await pushProduct(product, operation.operation);
      } else if (operation.tableName == 'lots') {
        final lot = LotModel.fromMap(payloadMap);
        await pushLot(lot, operation.operation);
      } else if (operation.tableName == 'sales') {
        final sale = SaleModel.fromMap(payloadMap);
        await pushSale(sale, operation.operation);
      } else {
        return SyncResult(success: false, errorMessage: 'Unknown table: ${operation.tableName}');
      }

      return SyncResult(success: true);
    } catch (e) {
      debugPrint('Firestore sync error: $e');
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  Future<void> pushProduct(ProductModel product, String operationType) async {
    final docRef = firestore.collection('products').doc(product.sku); // ID = sku
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      await docRef.set(product.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> pushLot(LotModel lot, String operationType) async {
    final docRef = firestore.collection('lots').doc(lot.id);
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      await docRef.set(lot.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> pushSale(SaleModel sale, String operationType) async {
    final docRef = firestore.collection('sales').doc(sale.id);
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      await docRef.set(sale.toMap(), SetOptions(merge: true));
    }
  }

  /// Listen to remote changes for Reactive UI/Real-time Updates (RNF-02)
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteInventoryChanges() {
    // For example, listen to 'products' collection changes.
    // In a full implementation, you might yield merged events from products and lots.
    return firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}
