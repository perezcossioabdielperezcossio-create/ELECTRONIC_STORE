import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<void> seedMasterAdminsRemote();
  Future<UserModel?> getUserByPhoneRemote(String celular);
  Future<void> saveUserRemote(UserModel user);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');

  @override
  Future<void> seedMasterAdminsRemote() async {
    try {
      for (final admin in UserModel.masterAdmins) {
        await _usersCol.doc(admin.celular).set(
              admin.toFirestore(),
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('Error al asegurar administradores maestros en Firestore: $e');
    }
  }

  @override
  Future<UserModel?> getUserByPhoneRemote(String celular) async {
    try {
      final doc = await _usersCol.doc(celular.trim()).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['celular'] = doc.id;
      return UserModel.fromMap(data);
    } catch (e) {
      debugPrint('Error al obtener usuario remoto de Firestore: $e');
      return null;
    }
  }

  @override
  Future<void> saveUserRemote(UserModel user) async {
    try {
      await _usersCol.doc(user.celular).set(
            user.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error al guardar usuario en Firestore: $e');
    }
  }
}
