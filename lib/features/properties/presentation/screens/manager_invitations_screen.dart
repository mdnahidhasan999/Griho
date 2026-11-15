// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ManagerInvitationsScreen extends ConsumerStatefulWidget {
  const ManagerInvitationsScreen({super.key});

  @override
  ConsumerState<ManagerInvitationsScreen> createState() =>
      _ManagerInvitationsScreenState();
}

class _ManagerInvitationsScreenState
    extends ConsumerState<ManagerInvitationsScreen> {
  bool _processing = false;

  Future<List<QueryDocumentSnapshot>> _fetchManagerInvites(
      dynamic profile,
      ) async {
    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('managerInvitations');
    final Map<String, QueryDocumentSnapshot> results = {};

    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final publicId = profile.publicId.toString().trim();
    final email = (profile.email ?? '').toString().trim();

    final queries = <Future<QuerySnapshot>>[
      if (uid.isNotEmpty) col.where('managerUserId', isEqualTo: uid).get(),
      if (uid.isNotEmpty) col.where('targetUserId', isEqualTo: uid).get(),
      if (phone.isNotEmpty) col.where('phone', isEqualTo: phone).get(),
      if (phone.isNotEmpty) col.where('identifier', isEqualTo: phone).get(),
      if (publicId.isNotEmpty)
        col.where('targetGrihoId', isEqualTo: publicId).get(),
      if (publicId.isNotEmpty)
        col.where('identifier', isEqualTo: publicId).get(),
      if (email.isNotEmpty) col.where('targetEmail', isEqualTo: email).get(),
    ];

    for (final future in queries) {
      try {
        final snap = await future;
        for (final doc in snap.docs) {
          results[doc.id] = doc;
        }
      } catch (_) {}
    }

    final list = results.values.toList();
    list.sort((a, b) {
      final aT =
          ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ??
              0;
      final bT =
          ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ??
              0;
      return bT.compareTo(aT);
    });
    return list;
  }

  Future<void> _respondToInvitation(
      QueryDocumentSnapshot doc,
      dynamic profile,
      bool accept,
      ) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final data = doc.data() as Map<String, dynamic>;
      final propertyId = (data['propertyId'] ?? '').toString().trim();
      final ownerId = (data['ownerId'] ?? '').toString().trim();

      final batch = firestore.batch();

      batch.update(doc.reference, {
        'status': accept ? 'accepted' : 'rejected',
        'accessStatus': accept ? 'active' : 'rejected',
        'managerUserId': profile.uid,
        'managerName': profile.name,
        'managerGrihoId': profile.publicId,
        'managerPhone': profile.phoneNumber,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (accept && propertyId.isNotEmpty) {
        final accessRef = firestore
            .collection('managerAccess')
            .doc('${profile.uid}_$propertyId');
        batch.set(accessRef, {
          'userId': profile.uid,
          'managerName': profile.name,
          'managerGrihoId': profile.publicId,
          'managerPhone': profile.phoneNumber,
          'ownerId': ownerId,
          'propertyId': propertyId,
          'propertyName': data['propertyName'] ?? 'Property',
          'propertyCode': data['propertyCode'] ?? '',
          'invitationId': doc.id,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final currentRoles = List<String>.from(profile.availableRoles ?? []);
        if (!currentRoles.contains('manager')) {
          batch.update(firestore.collection('users').doc(profile.uid), {
            'availableRoles': FieldValue.arrayUnion(['manager']),
            'defaultDashboard': 'manager',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      AuthRouteGuard.clearAccessCache();
      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation accepted! You now have manager access.'
                : 'Invitation declined.',
          ),
          backgroundColor: accept ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update invitation: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _toggleManagerStatus({
    required String invitationId,
    required String managerUserId,
    required String propertyId,
    required String managerName,
    required bool currentlyActive,
  }) async {
    if (_processing) return;

    final nextStatus = currentlyActive ? 'suspended' : 'active';
    final actionLabel = currentlyActive ? 'Suspend Access' : 'Restore Access';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel?'),
        content: Text(
          currentlyActive
              ? 'Temporarily suspend $managerName? They will immediately lose operational access until you restore it.'
              : 'Restore full operational manager access for $managerName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: currentlyActive
                ? FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.update(
        firestore.collection('managerInvitations').doc(invitationId),
        {'accessStatus': nextStatus, 'updatedAt': FieldValue.serverTimestamp()},
      );

      if (managerUserId.isNotEmpty && propertyId.isNotEmpty) {
        final accessRef = firestore
            .collection('managerAccess')
            .doc('${managerUserId}_$propertyId');
        batch.set(accessRef, {
          'status': nextStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? '$managerName has been suspended.'
                : '$managerName access restored.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _revokeManagerAccess({
    required String invitationId,
    required String managerUserId,
    required String propertyId,
    required String managerName,
  }) async {
    if (_processing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Manager Access?'),
        content: Text(
          'Permanently remove $managerName from managing this building? '
              'You will need to send a new invitation to assign them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke & Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.update(
        firestore.collection('managerInvitations').doc(invitationId),
        {
          'status': 'revoked',
          'accessStatus': 'revoked',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (managerUserId.isNotEmpty && propertyId.isNotEmpty) {
        final accessRef = firestore
            .collection('managerAccess')
            .doc('${managerUserId}_$propertyId');
        batch.set(accessRef, {
          'status': 'revoked',
          'revokedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access permanently revoked for $managerName.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke access: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _buildInviteList(
      BuildContext context,
      ThemeData theme,
      dynamic profile,
      bool isOwnerView,
      List<QueryDocumentSnapshot> docs,
      ) {
    final visibleDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString() != 'revoked';
    }).toList();

    if (visibleDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 56,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Text(
                isOwnerView
                    ? 'No manager invitations sent yet.'
                    : 'No invitations found for your account.',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOwnerView
                    ? 'Tap the button below to assign a manager to one of your buildings.'
                    : 'When a property owner invites you via your Phone (${profile?.phoneNumber}) or Griho ID (${profile?.publicId}), it will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isOwnerView) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push(RouteNames.addManager),
                  icon: const Icon(Icons.add),
                  label: const Text('Invite Manager'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: visibleDocs.length,
      itemBuilder: (context, index) {
        final doc = visibleDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['managerName'] ?? data['name'] ?? 'Manager')
            .toString();
        final identifier = (data['identifier'] ?? '').toString();
        final propertyName = (data['propertyName'] ?? 'Assigned Building')
            .toString();
        final propertyId = (data['propertyId'] ?? '').toString();
        final managerUserId = (data['managerUserId'] ?? '').toString();
        final status = (data['status'] ?? 'pending').toString();
        final accessStatus = (data['accessStatus'] ?? 'active').toString();

        final isPending = status == 'pending';
        final isAccepted = status == 'accepted';
        final isSuspended = isAccepted && accessStatus == 'suspended';

        final badgeLabel = isSuspended ? 'SUSPENDED' : status.toUpperCase();

        final statusColor = isSuspended
            ? Colors.orange.shade800
            : isAccepted
            ? Colors.green
            : isPending
            ? Colors.amber.shade900
            : Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSuspended
                  ? Colors.orange.shade700
                  : theme.colorScheme.outlineVariant,
              width: isSuspended ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.14),
                    child: Icon(
                      isSuspended
                          ? Icons.pause_circle_filled_rounded
                          : isAccepted
                          ? Icons.verified_user_rounded
                          : isPending
                          ? Icons.hourglass_top_rounded
                          : Icons.cancel_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Building: $propertyName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (identifier.isNotEmpty)
                          Text(
                            'Contact / ID: $identifier',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isOwnerView && isPending) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing
                            ? null
                            : () => _respondToInvitation(doc, profile, false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _processing
                            ? null
                            : () => _respondToInvitation(doc, profile, true),
                        child: const Text('Accept & Manage'),
                      ),
                    ),
                  ],
                ),
              ],
              if (isOwnerView && isAccepted) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processing
                            ? null
                            : () => _toggleManagerStatus(
                          invitationId: doc.id,
                          managerUserId: managerUserId,
                          propertyId: propertyId,
                          managerName: name,
                          currentlyActive: !isSuspended,
                        ),
                        icon: Icon(
                          isSuspended
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 18,
                        ),
                        label: Text(isSuspended ? 'Reactivate' : 'Suspend'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          backgroundColor: theme.colorScheme.error.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        onPressed: _processing
                            ? null
                            : () => _revokeManagerAccess(
                          invitationId: doc.id,
                          managerUserId: managerUserId,
                          propertyId: propertyId,
                          managerName: name,
                        ),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                        ),
                        label: const Text('Revoke Access'),
                      ),
                    ),
                  ],
                ),
              ],
              if (isOwnerView && isPending) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _processing
                        ? null
                        : () async {
                      await doc.reference.delete();
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Cancel Invite',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final firestore = FirebaseFirestore.instance;

    return profileAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profile not found')));
        }
        final isOwnerView = profile.defaultDashboard == 'owner';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isOwnerView
                  ? 'Property Managers & Invites'
                  : 'My Manager Invitations',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: isOwnerView
              ? StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('managerInvitations')
                .where('ownerId', isEqualTo: profile.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading invitations: ${snapshot.error}',
                  ),
                );
              }
              return _buildInviteList(
                context,
                theme,
                profile,
                true,
                snapshot.data?.docs ?? [],
              );
            },
          )
              : FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchManagerInvites(profile),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading invitations: ${snapshot.error}',
                  ),
                );
              }
              return _buildInviteList(
                context,
                theme,
                profile,
                false,
                snapshot.data ?? [],
              );
            },
          ),
          floatingActionButton: isOwnerView
              ? FloatingActionButton.extended(
            onPressed: () => context.push(RouteNames.addManager),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Invite Manager'),
          )
              : null,
        );
      },
    );
  }
}
