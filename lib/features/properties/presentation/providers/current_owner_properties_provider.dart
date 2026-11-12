import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/property_model.dart';
import '../../domain/entities/property.dart';

final currentOwnerPropertiesProvider =
FutureProvider.autoDispose<List<Property>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return [];

  final firestore = FirebaseFirestore.instance;
  final propertiesMap = <String, Property>{};

  // ১. মালিক হিসেবে নিজের প্রপার্টি লোড
  final ownedSnap = await firestore
      .collection('properties')
      .where('ownerId', isEqualTo: uid)
      .get();

  for (final doc in ownedSnap.docs) {
    propertiesMap[doc.id] = PropertyModel.fromFirestore(doc);
  }

  // ২. ম্যানেজার হিসেবে অ্যাসাইন করা প্রপার্টি লোড (managerAccess থেকে)
  final accessSnap = await firestore
      .collection('managerAccess')
      .where('userId', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .get();

  for (final doc in accessSnap.docs) {
    final propertyId = (doc.data()['propertyId'] ?? '').toString().trim();
    if (propertyId.isNotEmpty && !propertiesMap.containsKey(propertyId)) {
      final propDoc =
      await firestore.collection('properties').doc(propertyId).get();
      if (propDoc.exists) {
        propertiesMap[propDoc.id] = PropertyModel.fromFirestore(propDoc);
      }
    }
  }

  // ৩. ব্যাকআপ: যদি managerAccess কোনো কারণে মিসিং থাকে, managerInvitations থেকে লোড
  final acceptedInvites = await firestore
      .collection('managerInvitations')
      .where('managerUserId', isEqualTo: uid)
      .where('status', isEqualTo: 'accepted')
      .get();

  for (final doc in acceptedInvites.docs) {
    final propertyId = (doc.data()['propertyId'] ?? '').toString().trim();
    if (propertyId.isNotEmpty && !propertiesMap.containsKey(propertyId)) {
      final propDoc =
      await firestore.collection('properties').doc(propertyId).get();
      if (propDoc.exists) {
        propertiesMap[propDoc.id] = PropertyModel.fromFirestore(propDoc);
      }
    }
  }

  return propertiesMap.values.toList();
});