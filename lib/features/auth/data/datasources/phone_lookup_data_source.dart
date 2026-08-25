import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneLookupDataSource {
  final FirebaseFirestore _firestore;

  PhoneLookupDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'phone_lookups';

  CollectionReference<Map<String, dynamic>> get _phoneLookups {
    return _firestore.collection(_collectionName);
  }

  // ============================================================
  // GET USER DATA BY PHONE
  // ============================================================

  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    final document = await _phoneLookups.doc(normalizedPhone).get();

    if (!document.exists) {
      return null;
    }

    return document.data();
  }

  // ============================================================
  // SAVE USER PHONE LOOKUP
  // ============================================================

  Future<void> savePhoneLookup({
    required String phoneNumber,
    required String uid,
    required String publicId,
    required String name,
    String? email,
    String? nidNumber,
  }) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError('Phone number cannot be empty.');
    }

    if (uid.trim().isEmpty) {
      throw ArgumentError('User UID cannot be empty.');
    }

    await _phoneLookups.doc(normalizedPhone).set({
      'uid': uid,
      'publicId': publicId,
      'phoneNumber': normalizedPhone,
      'name': name,
      'email': email,
      'nidNumber': nidNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE PHONE LOOKUP
  // ============================================================

  Future<void> deletePhoneLookup(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();

    if (normalizedPhone.isEmpty) {
      return;
    }

    await _phoneLookups.doc(normalizedPhone).delete();
  }
}
