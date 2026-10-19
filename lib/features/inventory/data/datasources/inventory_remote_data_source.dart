import 'package:cloud_firestore/cloud_firestore.dart';

abstract class InventoryRemoteDataSource {
  Stream<QuerySnapshot<Map<String, dynamic>>> subscribeToLots({String? location});
  Future<void> updateWarehouseLotStock({
    required String lotId,
    required int newQuantity,
  });
  Future<void> createOrUpdateStoreLot(Map<String, dynamic> lotData);
}

class FirestoreInventoryRemoteDataSource implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;

  FirestoreInventoryRemoteDataSource({required this.firestore});

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> subscribeToLots({String? location}) {
    Query<Map<String, dynamic>> query = firestore.collection('lots');
    if (location != null && location.isNotEmpty) {
      query = query.where('location', isEqualTo: location);
    }
    return query.snapshots();
  }

  @override
  Future<void> updateWarehouseLotStock({
    required String lotId,
    required int newQuantity,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    await firestore.collection('lots').doc(lotId).update({
      'current_quantity': newQuantity,
      'current_qty': newQuantity,
      'is_active': newQuantity > 0 ? 1 : 0,
      'updated_at': nowIso,
    });
  }

  @override
  Future<void> createOrUpdateStoreLot(Map<String, dynamic> lotData) async {
    final lotId = lotData['id'] as String;
    await firestore.collection('lots').doc(lotId).set(lotData, SetOptions(merge: true));
  }
}
