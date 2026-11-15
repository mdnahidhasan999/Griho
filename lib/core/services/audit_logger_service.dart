// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLoggerService {
  AuditLoggerService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// যেকোনো গুরুত্বপূর্ণ অপারেশনের অডিট লগ রেকর্ড করার মেথড
  static Future<void> log({
    required String ownerId,
    required String propertyId,
    String? propertyName,
    required String
    category, // 'rent', 'billing', 'payment', 'tenant', 'manager'
    required String actionTitle,
    required String details,
    Map<String, dynamic>? metadata,
    String? actorRole, // 'owner' | 'manager' | 'caretaker' | 'electrician'
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final actorUid = currentUser.uid;
      final isOwner = actorUid == ownerId;
      final resolvedRole = actorRole ?? (isOwner ? 'owner' : 'manager');

      String actorName = isOwner ? 'Property Owner' : 'Manager';
      String actorGrihoId = '';

      // ইউজারের নাম ও Griho ID নিয়ে আসা
      final userDoc = await _firestore.collection('users').doc(actorUid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        actorName = (data['name'] ?? actorName).toString();
        actorGrihoId = (data['publicId'] ?? '').toString();
      }

      // প্রপার্টির নাম না থাকলে লোড করা
      String resolvedPropertyName = (propertyName ?? '').trim();
      if (resolvedPropertyName.isEmpty && propertyId.isNotEmpty) {
        final propDoc = await _firestore
            .collection('properties')
            .doc(propertyId)
            .get();
        if (propDoc.exists) {
          resolvedPropertyName = (propDoc.data()?['name'] ?? 'Building')
              .toString();
        }
      }

      await _firestore.collection('activityLogs').add({
        'ownerId': ownerId,
        'propertyId': propertyId,
        'propertyName': resolvedPropertyName.isEmpty
            ? 'Assigned Building'
            : resolvedPropertyName,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorGrihoId': actorGrihoId,
        'actorRole': resolvedRole,
        'category': category,
        'actionTitle': actionTitle,
        'details': details,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // লগিং কোনো কারণে ফেইল করলে যেন মূল অপারেশন আটকে না যায়
    }
  }
}
