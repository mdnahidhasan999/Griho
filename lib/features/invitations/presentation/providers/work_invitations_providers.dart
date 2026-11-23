// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

typedef WorkJsonMap = Map<String, dynamic>;
typedef WorkDocSnapshot = DocumentSnapshot<WorkJsonMap>;

/// A pending "work" invitation (manager / caretaker / electrician) addressed to
/// the signed-in user — independent of which console (role) they are in now.
class WorkInvitation {
  const WorkInvitation({required this.doc, required this.role});

  final WorkDocSnapshot doc;

  /// manager | caretaker | electrician
  final String role;

  WorkJsonMap get data => doc.data() ?? const {};

  bool get isManager => role == 'manager';

  String get propertyName => (data['propertyName'] ?? 'Property').toString();

  String get ownerName => (data['ownerName'] ?? 'Owner').toString();

  String get collection =>
      isManager ? 'managerInvitations' : 'staffInvitations';

  static String roleLabel(String role) {
    switch (role) {
      case 'manager':
        return 'Property Manager';
      case 'caretaker':
        return 'Caretaker';
      case 'electrician':
        return 'Electrician';
      default:
        return role;
    }
  }
}

Future<List<WorkInvitation>> fetchPendingWorkInvitations(
  dynamic profile,
) async {
  final db = FirebaseFirestore.instance;
  final uid = profile.uid.toString().trim();
  final phone = (profile.phoneNumber ?? '').toString().trim();
  final publicId = (profile.publicId ?? '').toString().trim();
  final email = (profile.email ?? '').toString().trim().toLowerCase();

  final found = <String, WorkInvitation>{};

  Future<void> run(String collection, String field, String value) async {
    if (value.isEmpty) {
      return;
    }
    try {
      final snap = await db
          .collection(collection)
          .where(field, isEqualTo: value)
          .where('status', isEqualTo: 'pending')
          .limit(20)
          .get();

      for (final d in snap.docs) {
        final data = d.data();
        if ((data['accessStatus'] ?? 'active') == 'revoked') {
          continue;
        }
        final role = collection == 'managerInvitations'
            ? 'manager'
            : (data['staffRole'] ?? data['role'] ?? 'caretaker').toString();
        if (role != 'manager' && role != 'caretaker' && role != 'electrician') {
          continue;
        }
        found['$collection/${d.id}'] = WorkInvitation(doc: d, role: role);
      }
    } catch (_) {}
  }

  final jobs = <Future<void>>[];
  for (final c in const ['managerInvitations', 'staffInvitations']) {
    jobs.add(
      run(c, c == 'managerInvitations' ? 'managerUserId' : 'staffUserId', uid),
    );
    jobs.add(run(c, 'phone', phone));
    jobs.add(run(c, 'targetGrihoId', publicId));
    jobs.add(run(c, 'targetEmail', email));
  }
  await Future.wait(jobs);

  final list = found.values.toList()
    ..sort((a, b) {
      int t(WorkInvitation i) => (i.data['createdAt'] is Timestamp)
          ? (i.data['createdAt'] as Timestamp).millisecondsSinceEpoch
          : 0;
      return t(b).compareTo(t(a));
    });
  return list;
}

/// Cached per authenticated profile; refreshed only when explicitly invalidated.
final pendingWorkInvitationsProvider = FutureProvider<List<WorkInvitation>>((
  ref,
) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null) {
    return const [];
  }
  return fetchPendingWorkInvitations(profile);
});
