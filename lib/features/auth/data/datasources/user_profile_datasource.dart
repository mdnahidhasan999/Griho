import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';

class UserProfileDataSource {
  final FirebaseFirestore _firestore;

  UserProfileDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _phoneLookupsCollection =>
      _firestore.collection('phone_lookups');

  CollectionReference<Map<String, dynamic>> get _publicIdsCollection =>
      _firestore.collection('public_ids');

  Future<AppUserModel?> getUserByUid(String uid) async {
    final document = await _usersCollection.doc(uid).get();

    if (!document.exists) {
      return null;
    }

    return AppUserModel.fromFirestore(document);
  }

  Future<void> createUser(AppUserModel user) async {
    final userDocument = _usersCollection.doc(user.uid);
    final batch = _firestore.batch();

    batch.set(
      userDocument,
      user.toFirestore(),
    );

    final phoneNumber = user.phoneNumber?.trim();

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final phoneLookupDocument =
      _phoneLookupsCollection.doc(phoneNumber);

      batch.set(
        phoneLookupDocument,
        {
          'phoneNumber': phoneNumber,
          'uid': user.uid,
          'publicId': user.publicId,
          'name': user.name,
          'email': user.email,
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
        SetOptions(merge: true),
      );
    }

    final publicId = user.publicId.trim();

    if (publicId.isNotEmpty) {
      final publicIdDocument =
      _publicIdsCollection.doc(publicId);

      batch.set(
        publicIdDocument,
        {
          'publicId': publicId,
          'uid': user.uid,
          'createdBy': user.uid,
          'name': user.name,
          'phoneNumber': phoneNumber,
          'email': user.email,
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> updateUser(AppUserModel user) async {
    final userDocument = _usersCollection.doc(user.uid);
    final batch = _firestore.batch();

    batch.update(
      userDocument,
      user.toFirestore(),
    );

    final phoneNumber = user.phoneNumber?.trim();

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final phoneLookupDocument =
      _phoneLookupsCollection.doc(phoneNumber);

      batch.set(
        phoneLookupDocument,
        {
          'phoneNumber': phoneNumber,
          'uid': user.uid,
          'publicId': user.publicId,
          'name': user.name,
          'email': user.email,
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
        SetOptions(merge: true),
      );
    }

    final publicId = user.publicId.trim();

    if (publicId.isNotEmpty) {
      final publicIdDocument =
      _publicIdsCollection.doc(publicId);

      batch.set(
        publicIdDocument,
        {
          'publicId': publicId,
          'uid': user.uid,
          'createdBy': user.uid,
          'name': user.name,
          'phoneNumber': phoneNumber,
          'email': user.email,
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<AppUserModel?> getUserByPublicId(String publicId) async {
    final normalizedPublicId = publicId.trim();

    if (normalizedPublicId.isEmpty) {
      return null;
    }

    final query = await _usersCollection
        .where(
      'publicId',
      isEqualTo: normalizedPublicId,
    )
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return AppUserModel.fromFirestore(
      query.docs.first,
    );
  }

  Future<AppUserModel?> getUserByPhone(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    final lookupDocument =
    await _phoneLookupsCollection.doc(normalizedPhone).get();

    if (!lookupDocument.exists) {
      return null;
    }

    final lookupData = lookupDocument.data();

    if (lookupData == null) {
      return null;
    }

    final uid = lookupData['uid'];

    if (uid is! String || uid
        .trim()
        .isEmpty) {
      return null;
    }

    return getUserByUid(uid);
  }
}