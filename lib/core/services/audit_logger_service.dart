// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef _JsonMap = Map<String, dynamic>;
typedef _DocSnap = DocumentSnapshot<_JsonMap>;

class AuditLoggerService {
  AuditLoggerService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? _cachedActorUid;
  static String? _cachedActorName;
  static String? _cachedActorGrihoId;
  static final Map<String, String> _propertyNameCache = <String, String>{};

  static void clearCache() {
    _cachedActorUid = null;
    _cachedActorName = null;
    _cachedActorGrihoId = null;
    _propertyNameCache.clear();
  }

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
      if (currentUser == null) {
        return;
      }

      final actorUid = currentUser.uid;
      final isOwner = actorUid == ownerId;
      final resolvedRole = actorRole ?? (isOwner ? 'owner' : 'manager');
      final normalizedPropId = propertyId.trim();

      String actorName = isOwner ? 'Property Owner' : 'Manager';
      String actorGrihoId = '';
      String resolvedPropertyName = (propertyName ?? '').trim();

      if (resolvedPropertyName.isNotEmpty && normalizedPropId.isNotEmpty) {
        _propertyNameCache[normalizedPropId] = resolvedPropertyName;
      } else if (resolvedPropertyName.isEmpty &&
          _propertyNameCache.containsKey(normalizedPropId)) {
        resolvedPropertyName = _propertyNameCache[normalizedPropId]!;
      }

      final needsActorFetch = _cachedActorUid != actorUid;
      final needsPropertyFetch =
          resolvedPropertyName.isEmpty && normalizedPropId.isNotEmpty;

      if (needsActorFetch || needsPropertyFetch) {
        final futures = <Future<_DocSnap>>[
          if (needsActorFetch)
            _firestore.collection('users').doc(actorUid).get(),
          if (needsPropertyFetch)
            _firestore.collection('properties').doc(normalizedPropId).get(),
        ];

        final results = await Future.wait(futures);
        var idx = 0;

        if (needsActorFetch) {
          final userDoc = results[idx++];
          final data = userDoc.data() ?? const <String, dynamic>{};
          _cachedActorUid = actorUid;
          _cachedActorName = (data['name'] ?? actorName).toString();
          _cachedActorGrihoId = (data['publicId'] ?? '').toString();
        }

        if (needsPropertyFetch) {
          final propDoc = results[idx];
          if (propDoc.exists) {
            final fetchedName = (propDoc.data()?['name'] ?? 'Building')
                .toString()
                .trim();
            if (fetchedName.isNotEmpty) {
              resolvedPropertyName = fetchedName;
              _propertyNameCache[normalizedPropId] = fetchedName;
            }
          }
        }
      }

      actorName = _cachedActorName ?? actorName;
      actorGrihoId = _cachedActorGrihoId ?? actorGrihoId;

      await _firestore.collection('activityLogs').add({
        'ownerId': ownerId,
        'propertyId': normalizedPropId,
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
        'metadata': metadata ?? const <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // লগিং কোনো কারণে ফেইল করলে যেন মূল অপারেশন আটকে না যায়
    }
  }
}
