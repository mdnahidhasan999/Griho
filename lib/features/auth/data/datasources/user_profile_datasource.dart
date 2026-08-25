import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';

class UserProfileDataSource {
  final FirebaseFirestore _firestore;

  UserProfileDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // COLLECTIONS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _phoneLookupsCollection {
    return _firestore.collection('phone_lookups');
  }

  // ============================================================
  // GET USER BY UID
  // ============================================================

  Future<AppUserModel?> getUserByUid(String uid) async {
    final document = await _usersCollection.doc(uid).get();

    if (!document.exists) {
      return null;
    }

    return AppUserModel.fromFirestore(document);
  }

  // ============================================================
  // CREATE USER
  // ============================================================

  Future<void> createUser(AppUserModel user) async {
    final userDocument = _usersCollection.doc(user.uid);

    final batch = _firestore.batch();

    // ----------------------------------------------------------
    // Create user profile
    // ----------------------------------------------------------

    batch.set(
      userDocument,
      user.toFirestore(),
    );

    // ----------------------------------------------------------
    // Create phone lookup
    //
    // Document ID = normalized phone number
    // ----------------------------------------------------------

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
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
      );
    }

    await batch.commit();
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  Future<void> updateUser(AppUserModel user) async {
    final userDocument = _usersCollection.doc(user.uid);

    final batch = _firestore.batch();

    // ----------------------------------------------------------
    // Update user profile
    // ----------------------------------------------------------

    batch.update(
      userDocument,
      user.toFirestore(),
    );

    // ----------------------------------------------------------
    // Update phone lookup
    // ----------------------------------------------------------

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
          'createdAt': Timestamp.fromDate(user.createdAt),
          'updatedAt': Timestamp.fromDate(user.updatedAt),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  // ============================================================
  // GET USER BY PUBLIC ID
  // ============================================================

  Future<AppUserModel?> getUserByPublicId(
      String publicId,
      ) async {
    final query = await _usersCollection
        .where(
      'publicId',
      isEqualTo: publicId,
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

  // ============================================================
  // GET USER BY PHONE
  // ============================================================

  Future<AppUserModel?> getUserByPhone(
      String phoneNumber,
      ) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // Step 1:
    // Find UID from phone lookup
    // ----------------------------------------------------------

    final lookupDocument =
    await _phoneLookupsCollection
        .doc(normalizedPhone)
        .get();

    if (!lookupDocument.exists) {
      return null;
    }

    final lookupData = lookupDocument.data();

    if (lookupData == null) {
      return null;
    }

    final uid = lookupData['uid'];

    if (uid is! String || uid.trim().isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // Step 2:
    // Get actual user profile
    // ----------------------------------------------------------

    return getUserByUid(uid);
  }
}