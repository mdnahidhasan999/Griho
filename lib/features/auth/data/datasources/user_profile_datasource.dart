import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';

class UserProfileDataSource {
  final FirebaseFirestore _firestore;

  UserProfileDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  Future<AppUserModel?> getUserByUid(String uid) async {
    final document = await _usersCollection.doc(uid).get();

    if (!document.exists) {
      return null;
    }

    return AppUserModel.fromFirestore(document);
  }

  Future<void> createUser(AppUserModel user) async {
    await _usersCollection.doc(user.uid).set(
      user.toFirestore(),
    );
  }

  Future<void> updateUser(AppUserModel user) async {
    await _usersCollection.doc(user.uid).update(
      user.toFirestore(),
    );
  }

  Future<AppUserModel?> getUserByPublicId(String publicId) async {
    final query = await _usersCollection
        .where('publicId', isEqualTo: publicId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return AppUserModel.fromFirestore(query.docs.first);
  }
}