// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/property_model.dart';
import '../../domain/entities/property.dart';

/// Cached per signed-in UID to avoid re-fetching on every tab switch.
/// Call `ref.invalidate(currentOwnerPropertiesProvider)` after mutations or pull-to-refresh.
final currentOwnerPropertiesProvider = FutureProvider<List<Property>>((
  ref,
) async {
  final uid = await ref.watch(
    authStateProvider.selectAsync((user) => user?.uid),
  );
  if (uid == null || uid.isEmpty) {
    return const [];
  }

  final firestore = FirebaseFirestore.instance;
  final propertiesMap = <String, Property>{};

  // Run owner, managerAccess, and accepted managerInvitations queries in parallel.
  final results = await Future.wait([
    firestore.collection('properties').where('ownerId', isEqualTo: uid).get(),
    firestore
        .collection('managerAccess')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get(),
    firestore
        .collection('managerInvitations')
        .where('managerUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get(),
  ]);

  for (final doc in results[0].docs) {
    propertiesMap[doc.id] = PropertyModel.fromFirestore(doc);
  }

  final missingPropertyIds = <String>{};

  for (final doc in results[1].docs) {
    final propertyId = (doc.data()['propertyId'] ?? '').toString().trim();
    if (propertyId.isNotEmpty && !propertiesMap.containsKey(propertyId)) {
      missingPropertyIds.add(propertyId);
    }
  }

  for (final doc in results[2].docs) {
    final data = doc.data();
    final accessStatus = (data['accessStatus'] ?? 'active').toString();
    if (accessStatus == 'suspended' || accessStatus == 'revoked') {
      continue;
    }
    final propertyId = (data['propertyId'] ?? '').toString().trim();
    if (propertyId.isNotEmpty && !propertiesMap.containsKey(propertyId)) {
      missingPropertyIds.add(propertyId);
    }
  }

  // Batch fetch managed properties in chunks of 10 using documentId whereIn.
  if (missingPropertyIds.isNotEmpty) {
    final idList = missingPropertyIds.toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < idList.length; i += 10) {
      final end = (i + 10) > idList.length ? idList.length : i + 10;
      chunks.add(idList.sublist(i, end));
    }

    await Future.wait(
      chunks.map((chunk) async {
        try {
          final snap = await firestore
              .collection('properties')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final propDoc in snap.docs) {
            propertiesMap[propDoc.id] = PropertyModel.fromFirestore(propDoc);
          }
        } catch (_) {}
      }),
    );
  }

  return propertiesMap.values.toList();
});
