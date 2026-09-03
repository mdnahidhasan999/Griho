import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrihoIdGenerator {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Random _random;

  GrihoIdGenerator({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    Random? random,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _random = random ?? Random.secure();

  static const String _characters =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static const int _idLength = 8;
  static const int _maxAttempts = 10;

  // ==========================================================================
  // GENERATE AND RESERVE
  // ==========================================================================

  Future<String> generateAndReserve() async {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'A Firebase authenticated user is required to generate a Griho ID.',
      );
    }

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final publicId = _generateId();

      final reservationRef = _firestore
          .collection('public_ids')
          .doc(publicId);

      final reserved = await _firestore.runTransaction<bool>(
            (transaction) async {
          final snapshot = await transaction.get(reservationRef);

          // ---------------------------------------------------------------
          // ID ALREADY EXISTS
          // ---------------------------------------------------------------

          if (snapshot.exists) {
            return false;
          }

          // ---------------------------------------------------------------
          // RESERVE NEW ID
          // ---------------------------------------------------------------

          transaction.set(
            reservationRef,
            {
              'publicId': publicId,
              'uid': currentUser.uid,
              'createdBy': currentUser.uid,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );

          return true;
        },
      );

      if (reserved) {
        return publicId;
      }
    }

    throw StateError(
      'Unable to generate a unique Griho ID after $_maxAttempts attempts.',
    );
  }

  // ==========================================================================
  // RELEASE RESERVATION
  // ==========================================================================

  Future<void> releaseReservation(String publicId) async {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      return;
    }

    final normalizedPublicId = publicId.trim();

    if (normalizedPublicId.isEmpty) {
      return;
    }

    final reservationRef = _firestore
        .collection('public_ids')
        .doc(normalizedPublicId);

    final snapshot = await reservationRef.get();

    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();

    if (data == null) {
      return;
    }

    final createdBy = data['createdBy'];

    if (createdBy != currentUser.uid) {
      return;
    }

    await reservationRef.delete();
  }

  // ==========================================================================
  // GENERATE ID
  // ==========================================================================

  String _generateId() {
    final buffer = StringBuffer();

    for (var i = 0; i < _idLength; i++) {
      final index = _random.nextInt(_characters.length);
      buffer.write(_characters[index]);
    }

    return 'GRI-${buffer.toString()}';
  }
}