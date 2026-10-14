import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'remote_sync_datasource.dart';
import '../models/sync_operation_model.dart';
import '../../../../features/inventory/data/models/product_model.dart';
import '../../../../features/inventory/data/models/lot_model.dart';
import '../../../../features/pos/data/models/sale_model.dart';
import '../../../../features/pos/data/models/sale_detail_model.dart';
import '../../../../features/clients/data/models/client_model.dart';
import '../../../../features/deliveries/data/models/delivery_model.dart';

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

      if (operation.tableName == 'clients' || operation.tableName == 'clientes' || operation.tableName == 'customers') {
        if (operation.operation == 'DELETE') {
          final clientId = (payloadMap['id'] as String?) ?? operation.id;
          await deleteClient(clientId);
        } else {
          final client = ClientModel.fromMap(payloadMap);
          await saveClient(client);
        }
      } else if (operation.tableName == 'deliveries' || operation.tableName == 'repartidores') {
        if (operation.operation == 'DELETE') {
          final deliveryId = (payloadMap['id'] as String?) ?? operation.id;
          await deleteDelivery(deliveryId);
        } else {
          final delivery = DeliveryModel.fromMap(payloadMap);
          await saveDelivery(delivery);
        }
      } else if (operation.tableName == 'products' || operation.tableName == 'productos') {
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
          payloadMap['status'] = 'COMPLETED';
          payloadMap['is_locked'] = true;
          payloadMap['origen_venta'] = 'ALMACEN';
          payloadMap['store_location'] = 'ALMACEN';
          final sale = SaleModel.fromMap(payloadMap);
          final rawDetails = payloadMap['sale_details'] ?? payloadMap['items'];
          final details = <SaleDetailModel>[];
          if (rawDetails is List) {
            for (final d in rawDetails) {
              if (d is Map) {
                details.add(SaleDetailModel.fromMap(Map<String, dynamic>.from(d)));
              }
            }
          }
          await saveSaleTransaction(sale, details);
        }
      } else if (operation.tableName == 'ventas_vendedor' || operation.tableName == 'seller_sales') {
        final saleId = (payloadMap['id'] as String?) ?? operation.id;
        if (operation.operation == 'DELETE') {
          await firestore.collection('seller_sales').doc(saleId).delete();
        } else {
          await saveSellerSale(payloadMap, saleId);
        }
      } else if (operation.tableName == 'sale_items' || operation.tableName == 'detalle_ventas') {
        // Individual item or detail
        final detail = SaleDetailModel.fromMap(payloadMap);
        final docRef = firestore.collection('sales').doc(detail.ventaId).collection('sale_details').doc(detail.id);
        await docRef.set(detail.toMap(), SetOptions(merge: true));
      } else {
        return SyncResult(success: false, errorMessage: 'Unknown table: ${operation.tableName}');
      }

      return SyncResult(success: true);
    } catch (e) {
      debugPrint('Firestore sync error: $e');
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  /// Guarda un repartidor/delivery en la colección 'deliveries' usando delivery.id como Doc ID
  Future<void> saveDelivery(DeliveryModel delivery) async {
    final docRef = firestore.collection('deliveries').doc(delivery.id);
    await docRef.set(delivery.toMap(), SetOptions(merge: true));
  }

  /// Elimina un repartidor de Firestore
  Future<void> deleteDelivery(String deliveryId) async {
    await firestore.collection('deliveries').doc(deliveryId).delete();
  }

  /// Guarda un cliente en la colección 'clients' usando client.id como Doc ID
  Future<void> saveClient(ClientModel client) async {
    final docRef = firestore.collection('clients').doc(client.id);
    await docRef.set(client.toMap(), SetOptions(merge: true));
  }

  /// Elimina un cliente de Firestore
  Future<void> deleteClient(String clientId) async {
    await firestore.collection('clients').doc(clientId).delete();
  }

  /// Guarda una transacción de venta completa con cabecera y desglose detallado
  Future<void> saveSaleTransaction(SaleModel sale, List<SaleDetailModel> details) async {
    final docRef = firestore.collection('sales').doc(sale.id);
    final saleMap = sale.toMap();
    saleMap['status'] = 'COMPLETED';
    saleMap['is_locked'] = true;
    
    if (details.isNotEmpty) {
      final detailsMapList = details.map((d) => d.toMap()).toList();
      saleMap['sale_details'] = detailsMapList;
      saleMap['items'] = detailsMapList;
    }
    
    await docRef.set(saleMap, SetOptions(merge: true));
  }

  /// Guarda una venta de vendedor en la colección independiente 'seller_sales'
  Future<void> saveSellerSale(Map<String, dynamic> payloadMap, String saleId) async {
    final docRef = firestore.collection('seller_sales').doc(saleId);

    // Process items ensuring exact requested schema
    dynamic rawItems = payloadMap['items'];
    if (rawItems is String) {
      try {
        rawItems = jsonDecode(rawItems);
      } catch (_) {
        rawItems = [];
      }
    }
    final itemsList = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final i in rawItems) {
        if (i is Map) {
          itemsList.add({
            'product_id': (i['product_id'] ?? '').toString(),
            'product_name': (i['product_name'] ?? '').toString(),
            'cantidad': (i['cantidad'] as num?)?.toInt() ?? (i['quantity'] as num?)?.toInt() ?? 1,
            'precio_unitario': (i['precio_unitario'] as num?)?.toDouble() ?? (i['unit_price'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }
    }

    final sellerDoc = <String, dynamic>{
      'id': saleId,
      'usuario_id': (payloadMap['usuario_id'] ?? '').toString(),
      'vendedor_nombre': (payloadMap['vendedor_nombre'] ?? '').toString(),
      'cliente_nombre': (payloadMap['cliente_nombre'] ?? payloadMap['customer_name'] ?? 'Cliente Mostrador').toString(),
      'fecha_venta': (payloadMap['fecha_venta'] ?? payloadMap['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      'total_cobrado': ((payloadMap['total_cobrado'] ?? payloadMap['total'] ?? 0) as num).toDouble(),
      'metodo_pago': (payloadMap['metodo_pago'] ?? payloadMap['payment_method'] ?? 'EFECTIVO').toString(),
      'status': (payloadMap['status'] ?? 'COMPLETED').toString(),
      'is_locked': 1,
      'items': itemsList,
    };

    if (payloadMap['clientTimestamp'] != null) {
      sellerDoc['clientTimestamp'] = payloadMap['clientTimestamp'];
    }
    if (payloadMap['lastModified'] != null) {
      sellerDoc['lastModified'] = payloadMap['lastModified'];
    }

    await docRef.set(sellerDoc, SetOptions(merge: true));
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
      mapToSet['location'] = lot.location;
      mapToSet['ubicacion'] = lot.location;
      mapToSet['is_active'] = lot.isActive ? 1 : 0;
      await docRef.set(mapToSet, SetOptions(merge: true));
    }
  }

  Future<void> pushSale(SaleModel sale, String operationType, [Map<String, dynamic>? fullPayload]) async {
    final docRef = firestore.collection('sales').doc(sale.id);
    if (operationType == 'DELETE') {
      await docRef.delete();
    } else {
      final mapToSet = fullPayload != null ? Map<String, dynamic>.from(fullPayload) : sale.toMap();
      mapToSet['status'] = 'COMPLETED';
      mapToSet['is_locked'] = true;
      await docRef.set(mapToSet, SetOptions(merge: true));
    }
  }

  /// Listen to remote changes for Deliveries (Repartidores)
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteDeliveries() {
    return firestore.collection('deliveries').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
  }

  /// Listen to remote changes for Clients (CRM)
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteClients() {
    return firestore.collection('clients').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
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

  /// Listen to remote changes for Users
  @override
  Stream<List<Map<String, dynamic>>> listenToRemoteUsers() {
    return firestore.collection('users').snapshots().map((snapshot) {
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

  /// Listen to remote changes for Seller Sales (isolated collection 'seller_sales')
  @override
  Stream<List<Map<String, dynamic>>> listenToSellerSales(String sellerPhone) {
    return firestore
        .collection('seller_sales')
        .where('usuario_id', isEqualTo: sellerPhone)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return data;
      }).toList();
    });
  }

  /// Fetch seller sales on-demand (e.g. for Admin Store Audit)
  @override
  Future<List<Map<String, dynamic>>> fetchSellerSales({String? sellerPhone}) async {
    Query<Map<String, dynamic>> query = firestore.collection('seller_sales');
    if (sellerPhone != null && sellerPhone.isNotEmpty) {
      query = query.where('usuario_id', isEqualTo: sellerPhone);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] ??= doc.id;
      return data;
    }).toList();
  }
}
