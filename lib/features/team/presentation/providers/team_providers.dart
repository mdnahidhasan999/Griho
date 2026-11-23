// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

typedef TeamJsonMap = Map<String, dynamic>;
typedef TeamDocSnapshot = QueryDocumentSnapshot<TeamJsonMap>;

String _s(Object? v) => (v ?? '').toString().trim();

/// একজন টিম সদস্য (ম্যানেজার / কেয়ারটেকার / ইলেক্ট্রিশিয়ান) অথবা পেন্ডিং আমন্ত্রণ।
class TeamMember {
  const TeamMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.contact,
    required this.role,
    required this.propertyId,
    required this.propertyName,
    required this.status,
    required this.invitationId,
    required this.isInvite,
  });

  /// Firestore document id (access বা invitation).
  final String id;
  final String userId;
  final String name;
  final String contact;

  /// 'manager' | 'caretaker' | 'electrician'
  final String role;
  final String propertyId;
  final String propertyName;

  /// 'active' | 'suspended' | 'revoked' | 'pending'
  final String status;
  final String invitationId;
  final bool isInvite;

  bool get isManager => role == 'manager';

  String get accessCollection => isManager ? 'managerAccess' : 'staffAccess';

  String get invitationCollection =>
      isManager ? 'managerInvitations' : 'staffInvitations';

  String get roleLabel => switch (role) {
    'manager' => 'Manager',
    'caretaker' => 'Caretaker',
    'electrician' => 'Electrician',
    _ => role,
  };

  IconData get roleIcon => switch (role) {
    'manager' => Iconsax.shield_tick,
    'caretaker' => Iconsax.broom,
    'electrician' => Iconsax.electricity,
    _ => Iconsax.user,
  };

  factory TeamMember.fromAccess(TeamDocSnapshot doc, String? fixedRole) {
    final d = doc.data();
    final name = _s(d['managerName'] ?? d['staffName'] ?? d['name']);
    final contact = _s(
      d['managerPhone'] ??
          d['staffPhone'] ??
          d['managerGrihoId'] ??
          d['staffGrihoId'],
    );
    return TeamMember(
      id: doc.id,
      userId: _s(d['userId']),
      name: name.isEmpty ? 'Unnamed' : name,
      contact: contact,
      role: fixedRole ?? _s(d['staffRole']),
      propertyId: _s(d['propertyId']),
      propertyName: _s(d['propertyName']).isEmpty
          ? 'Building'
          : _s(d['propertyName']),
      status: _s(d['status']).isEmpty ? 'active' : _s(d['status']),
      invitationId: _s(d['invitationId']),
      isInvite: false,
    );
  }

  factory TeamMember.fromInvite(TeamDocSnapshot doc, String? fixedRole) {
    final d = doc.data();
    final name = _s(d['name'] ?? d['managerName'] ?? d['staffName']);
    final identifier = _s(d['identifier']);
    return TeamMember(
      id: doc.id,
      userId: _s(d['managerUserId'] ?? d['targetUserId']),
      name: name.isNotEmpty
          ? name
          : (identifier.isNotEmpty ? identifier : 'Invited user'),
      contact: identifier,
      role: fixedRole ?? _s(d['staffRole']),
      propertyId: _s(d['propertyId']),
      propertyName: _s(d['propertyName']).isEmpty
          ? 'Building'
          : _s(d['propertyName']),
      status: 'pending',
      invitationId: doc.id,
      isInvite: true,
    );
  }
}

/// একটি কাজ (Work order).
class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.title,
    required this.description,
    required this.unitName,
    required this.category,
    required this.status,
    required this.propertyId,
    required this.propertyName,
    required this.assignedToUid,
    required this.assignedToName,
    required this.assignedRole,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String unitName;

  /// 'electrical' | 'plumbing' | 'general'
  final String category;

  /// 'open' | 'assigned' | 'in_progress' | 'resolved' | 'cancelled'
  final String status;
  final String propertyId;
  final String propertyName;
  final String assignedToUid;
  final String assignedToName;
  final String assignedRole;
  final DateTime? createdAt;

  bool get isOpenish =>
      status == 'open' || status == 'assigned' || status == 'in_progress';

  factory WorkOrder.fromDoc(TeamDocSnapshot doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    return WorkOrder(
      id: doc.id,
      title: _s(d['title']),
      description: _s(d['description']),
      unitName: _s(d['unitName']).isEmpty ? 'Common Area' : _s(d['unitName']),
      category: _s(d['category']).isEmpty ? 'general' : _s(d['category']),
      status: _s(d['status']).isEmpty ? 'open' : _s(d['status']),
      propertyId: _s(d['propertyId']),
      propertyName: _s(d['propertyName']),
      assignedToUid: _s(d['assignedToUid']),
      assignedToName: _s(d['assignedToName']),
      assignedRole: _s(d['assignedRole']),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

Stream<List<TeamMember>> _accessStream(
    Ref ref,
    String collection,
    String? fixedRole,
    ) {
  ref.watch(authStateProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const <TeamMember>[]);
  }
  return FirebaseFirestore.instance
      .collection(collection)
      .where('ownerId', isEqualTo: uid)
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => TeamMember.fromAccess(d, fixedRole)).toList(),
  );
}

Stream<List<TeamMember>> _pendingStream(
    Ref ref,
    String collection,
    String? fixedRole,
    ) {
  ref.watch(authStateProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const <TeamMember>[]);
  }
  return FirebaseFirestore.instance
      .collection(collection)
      .where('ownerId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => TeamMember.fromInvite(d, fixedRole)).toList(),
  );
}

final ownerManagersProvider = StreamProvider.autoDispose<List<TeamMember>>(
      (ref) => _accessStream(ref, 'managerAccess', 'manager'),
);

final ownerStaffProvider = StreamProvider.autoDispose<List<TeamMember>>(
      (ref) => _accessStream(ref, 'staffAccess', null),
);

final ownerPendingManagerInvitesProvider =
StreamProvider.autoDispose<List<TeamMember>>(
      (ref) => _pendingStream(ref, 'managerInvitations', 'manager'),
);

final ownerPendingStaffInvitesProvider =
StreamProvider.autoDispose<List<TeamMember>>(
      (ref) => _pendingStream(ref, 'staffInvitations', null),
);

final ownerWorkOrdersProvider = StreamProvider.autoDispose<List<WorkOrder>>((
    ref,
    ) {
  ref.watch(authStateProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const <WorkOrder>[]);
  }
  return FirebaseFirestore.instance
      .collection('maintenanceRequests')
      .where('ownerId', isEqualTo: uid)
      .limit(150)
      .snapshots()
      .map((s) {
    final list = s.docs.map(WorkOrder.fromDoc).toList()
      ..sort(
            (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    return list;
  });
});