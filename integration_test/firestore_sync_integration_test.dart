import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:electronic_store/firebase_options.dart';
import 'package:electronic_store/core/sync/data/datasources/firestore_remote_data_source.dart';
import 'package:electronic_store/features/inventory/data/models/product_model.dart';
import 'package:electronic_store/features/inventory/data/models/lot_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firestore Sync Integration Test', () {
    late FirebaseFirestore firestore;
    late FirestoreRemoteDataSource remoteDataSource;
    
    final testProductId = const Uuid().v4();
    final testLotId = const Uuid().v4();
    final testSku = 'TEST-SKU-${DateTime.now().millisecondsSinceEpoch}';

    setUpAll(() async {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('Firebase ya inicializado en el test: $e');
      }
      
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Error signInAnonymously: $e');
      }

      firestore = FirebaseFirestore.instance;
      remoteDataSource = FirestoreRemoteDataSource(firestore: firestore);
    });

    tearDownAll(() async {
      // Clean up records from Firestore
      await firestore.collection('products').doc(testSku).delete();
      await firestore.collection('lots').doc(testLotId).delete();
    });

    testWidgets('Alta remota de producto y lote (Push) y recepción de cambios (Stream) en < 3000ms', (tester) async {
      final stopwatch = Stopwatch()..start();

      final product = ProductModel(
        id: testProductId,
        sku: testSku,
        name: 'Integration Test Product',
        brand: 'Test Brand',
        category: 'Test Category',
        standardSellingPrice: 150.0,
        minStockThreshold: 10,
      );

      final lot = LotModel(
        id: testLotId,
        productId: testProductId, // Note: The schema links by product.id usually, but for this test, we just push it.
        purchaseDate: DateTime.now(),
        initialQuantity: 50,
        currentQuantity: 50,
        realUnitCost: 100.0,
      );

      // Listen to the stream and wait for our specific product to appear
      final completer = Completer<bool>();
      
      final subscription = remoteDataSource.listenToRemoteInventoryChanges().listen((products) {
        if (products.any((p) => p['sku'] == testSku)) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });

      // 2. Probar el alta remota
      await remoteDataSource.pushProduct(product, 'CREATE');
      await remoteDataSource.pushLot(lot, 'CREATE');

      // 3. Probar la recepción de cambios en tiempo real vía Stream (timeout < 3000ms)
      final received = await completer.future.timeout(
        const Duration(milliseconds: 3000),
        onTimeout: () => false,
      );

      stopwatch.stop();
      
      subscription.cancel();

      expect(received, isTrue, reason: 'El cambio no se recibió en el Stream dentro de los 3000ms permitidos.');
      expect(stopwatch.elapsedMilliseconds, lessThan(3000), reason: 'El tiempo total de push y recepción excedió los 3000ms.');
      
      // Verify documents actually exist in Firestore
      final productDoc = await firestore.collection('products').doc(testSku).get();
      expect(productDoc.exists, isTrue);
      expect(productDoc.data()?['sku'], testSku);

      final lotDoc = await firestore.collection('lots').doc(testLotId).get();
      expect(lotDoc.exists, isTrue);
      expect(lotDoc.data()?['id'], testLotId);
    });
  });
}
