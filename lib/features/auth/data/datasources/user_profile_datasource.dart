import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user_model.dart';

class UserProfileDataSource {
  final FirebaseFirestore _firestore;

  UserProfileDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

    batch.set(userDocument, user.toFirestore());

    final phoneNumber = user.phoneNumber?.trim();

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final phoneLookupDocument = _phoneLookupsCollection.doc(phoneNumber);

      batch.set(phoneLookupDocument, {
        'phoneNumber': phoneNumber,
        'uid': user.uid,
        'publicId': user.publicId,
        'name': user.name,
        'email': user.email,
        'createdAt': Timestamp.fromDate(user.createdAt),
        'updatedAt': Timestamp.fromDate(user.updatedAt),
      }, SetOptions(merge: true));
    }

    final publicId = user.publicId.trim();

    if (publicId.isNotEmpty) {
      final publicIdDocument = _publicIdsCollection.doc(publicId);

      batch.set(publicIdDocument, {
        'publicId': publicId,
        'uid': user.uid,
        'createdBy': user.uid,
        'name': user.name,
        'phoneNumber': phoneNumber,
        'email': user.email,
        'createdAt': Timestamp.fromDate(user.createdAt),
        'updatedAt': Timestamp.fromDate(user.updatedAt),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> updateUser(AppUserModel user) async {
    final userDocument = _usersCollection.doc(user.uid);
    final batch = _firestore.batch();

    batch.update(userDocument, user.toFirestore());

    final phoneNumber = user.phoneNumber?.trim();

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final phoneLookupDocument = _phoneLookupsCollection.doc(phoneNumber);

      batch.set(phoneLookupDocument, {
        'phoneNumber': phoneNumber,
        'uid': user.uid,
        'publicId': user.publicId,
        'name': user.name,
        'email': user.email,
        'createdAt': Timestamp.fromDate(user.createdAt),
        'updatedAt': Timestamp.fromDate(user.updatedAt),
      }, SetOptions(merge: true));
    }

    final publicId = user.publicId.trim();

    if (publicId.isNotEmpty) {
      final publicIdDocument = _publicIdsCollection.doc(publicId);

      batch.set(publicIdDocument, {
        'publicId': publicId,
        'uid': user.uid,
        'createdBy': user.uid,
        'name': user.name,
        'phoneNumber': phoneNumber,
        'email': user.email,
        'createdAt': Timestamp.fromDate(user.createdAt),
        'updatedAt': Timestamp.fromDate(user.updatedAt),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Updates only the fields a user is allowed to change on their profile.
  Future<void> updateProfile({
    required String uid,
    required String publicId,
    required String? phoneNumber,
    required String name,
    required String? email,
    required String? photoUrl,
    String? nidNumber,
  }) async {
    final userDocument = _usersCollection.doc(uid);

    // Main profile document: only name, email, photoUrl and updatedAt.
    await userDocument.update({
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'nidNumber': nidNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Keep the resident records linked to this account up to date, so the
    // owner sees the tenant's current email and NID. Best effort only.
    try {
      final normalizedEmail = email?.trim();
      final normalizedNid = nidNumber?.trim();

      final contact = <String, dynamic>{
        if (normalizedEmail != null && normalizedEmail.isNotEmpty)
          'email': normalizedEmail.toLowerCase(),
        if (normalizedNid != null && normalizedNid.isNotEmpty)
          'nidNumber': normalizedNid,
      };

      if (contact.isNotEmpty) {
        final linkedTenants = await _firestore
            .collection('tenants')
            .where('userId', isEqualTo: uid)
            .get();

        for (final tenantDocument in linkedTenants.docs) {
          await tenantDocument.reference.update({
            ...contact,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (error) {
      debugPrint('Resident contact sync failed: $error');
    }
    // Lookup copies are best effort. A failure must not lose the profile save.
    try {
      final batch = _firestore.batch();
      final normalizedPhone = phoneNumber?.trim();

      if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
        batch.set(_phoneLookupsCollection.doc(normalizedPhone), {
          'phoneNumber': normalizedPhone,
          'uid': uid,
          'publicId': publicId,
          'name': name,
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final normalizedPublicId = publicId.trim();

      if (normalizedPublicId.isNotEmpty) {
        batch.set(_publicIdsCollection.doc(normalizedPublicId), {
          'publicId': normalizedPublicId,
          'uid': uid,
          'createdBy': uid,
          'name': name,
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (error) {
      debugPrint('Profile lookup sync failed: $error');
    }
  }

  Future<void> saveOwnerRole(String uid) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    final userDocument = _usersCollection.doc(normalizedUid);
    final snapshot = await userDocument.get();

    if (!snapshot.exists) {
      throw StateError('User profile does not exist.');
    }

    final data = snapshot.data();

    if (data == null) {
      throw StateError('User profile data is unavailable.');
    }

    final phoneNumber = data['phoneNumber'];

    if (phoneNumber is! String || phoneNumber
        .trim()
        .isEmpty) {
      throw StateError('Complete your profile before selecting a role.');
    }

    final rawRoles = data['availableRoles'];
    final existingRoles = rawRoles is List
        ? rawRoles.whereType<String>().toSet()
        : <String>{};

    existingRoles.add('owner');

    await userDocument.update({
      'availableRoles': existingRoles.toList(),
      'defaultDashboard': 'owner',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDefaultDashboard({
    required String uid,
    required String role,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedRole = role.trim().toLowerCase();

    const allowedRoles = {
      'owner',
      'manager',
      'caretaker',
      'tenant',
      'electrician',
    };

    if (normalizedUid.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    if (!allowedRoles.contains(normalizedRole)) {
      throw ArgumentError('Invalid dashboard role.');
    }

    final userDocument = _usersCollection.doc(normalizedUid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocument);

      if (!snapshot.exists) {
        throw StateError('User profile does not exist.');
      }

      final data = snapshot.data();

      if (data == null) {
        throw StateError('User profile data is unavailable.');
      }

      final rawRoles = data['availableRoles'];

      final availableRoles = rawRoles is List
          ? rawRoles
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .toSet()
          : <String>{};

      if (!availableRoles.contains(normalizedRole)) {
        throw StateError('You are not authorized to use this dashboard.');
      }

      final phoneNumber = data['phoneNumber'];

      if (phoneNumber is! String || phoneNumber
          .trim()
          .isEmpty) {
        throw StateError(
          'Complete your profile before changing the default dashboard.',
        );
      }

      transaction.update(userDocument, {
        'defaultDashboard': normalizedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveInitialRole(String uid, String role) async {
    final normalizedUid = uid.trim();

    const allowedRoles = {
      'owner',
      'tenant',
      'manager',
      'caretaker',
      'electrician',
    };

    if (normalizedUid.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    if (!allowedRoles.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }

    final userDocument = _usersCollection.doc(normalizedUid);
    final snapshot = await userDocument.get();

    if (!snapshot.exists) {
      throw StateError('User profile does not exist.');
    }

    final data = snapshot.data();

    if (data == null) {
      throw StateError('User profile data is unavailable.');
    }

    final phoneNumber = data['phoneNumber'];

    if (phoneNumber is! String || phoneNumber
        .trim()
        .isEmpty) {
      throw StateError('Complete your profile before selecting a role.');
    }

    final rawRoles = data['availableRoles'];

    final existingRoles = rawRoles is List
        ? rawRoles.whereType<String>().toSet()
        : <String>{};

    final rawDashboard = data['defaultDashboard'];

    final hasExistingRole =
        existingRoles.isNotEmpty ||
            (rawDashboard is String && rawDashboard
                .trim()
                .isNotEmpty);

    if (hasExistingRole) {
      throw StateError('A role has already been selected for this profile.');
    }

    await userDocument.update({
      'availableRoles': [role],
      'defaultDashboard': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUserModel?> getUserByPublicId(String publicId) async {
    final normalizedPublicId = publicId.trim();

    if (normalizedPublicId.isEmpty) {
      return null;
    }

    final query = await _usersCollection
        .where('publicId', isEqualTo: normalizedPublicId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return AppUserModel.fromFirestore(query.docs.first);
  }

  Future<AppUserModel?> getUserByPhone(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    final lookupDocument = await _phoneLookupsCollection
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

    if (uid is! String || uid
        .trim()
        .isEmpty) {
      return null;
    }

    return getUserByUid(uid);
  }
}
