import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class GrihoIdGenerator {
  final FirebaseFirestore _firestore;
  final Random _random;

  GrihoIdGenerator({
    FirebaseFirestore? firestore,
    Random? random,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  static const String _characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _idLength = 8;
  static const int _maxAttempts = 10;

  Future<String> generateAndReserve() async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final publicId = _generateId();

      final reservationRef = _firestore
          .collection('public_ids')
          .doc(publicId);

      try {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(reservationRef);

          if (snapshot.exists) {
            throw _IdAlreadyExistsException();
          }

          transaction.set(reservationRef, {
            'publicId': publicId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        return publicId;
      } on _IdAlreadyExistsException {
        continue;
      }
    }

    throw StateError(
      'Unable to generate a unique Griho ID after $_maxAttempts attempts.',
    );
  }

  Future<void> releaseReservation(String publicId) async {
    await _firestore
        .collection('public_ids')
        .doc(publicId)
        .delete();
  }

  String _generateId() {
    final buffer = StringBuffer();

    for (var i = 0; i < _idLength; i++) {
      final index = _random.nextInt(_characters.length);
      buffer.write(_characters[index]);
    }

    return 'GRI-${buffer.toString()}';
  }
}

class _IdAlreadyExistsException implements Exception {}