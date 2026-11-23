// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

typedef _InviteJson = Map<String, dynamic>;
typedef _InviteDocList = List<QueryDocumentSnapshot>;

_InviteJson _inviteMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

class ManagerInvitationsScreen extends ConsumerStatefulWidget {
  const ManagerInvitationsScreen({super.key});

  @override
  ConsumerState<ManagerInvitationsScreen> createState() =>
      _ManagerInvitationsScreenState();
}

class _ManagerInvitationsScreenState
    extends ConsumerState<ManagerInvitationsScreen> {
  bool _processing = false;

  Stream<QuerySnapshot>? _ownerInvitesStream;
  String? _ownerStreamUid;

  Future<_InviteDocList>? _managerInvitesFuture;
  String? _managerFutureUid;

  Stream<QuerySnapshot> _getOwnerStream(String uid) {
    if (_ownerInvitesStream == null || _ownerStreamUid != uid) {
      _ownerStreamUid = uid;
      _ownerInvitesStream = FirebaseFirestore.instance
          .collection('managerInvitations')
          .where('ownerId', isEqualTo: uid)
          .limit(50)
          .snapshots();
    }
    return _ownerInvitesStream!;
  }

  Future<_InviteDocList> _getManagerInvites(dynamic profile) {
    final uid = profile.uid.toString().trim();
    if (_managerInvitesFuture == null || _managerFutureUid != uid) {
      _managerFutureUid = uid;
      _managerInvitesFuture = _fetchManagerInvites(profile);
    }
    return _managerInvitesFuture!;
  }

  void _refreshManagerInvites(dynamic profile) {
    setState(() {
      _managerFutureUid = profile.uid.toString().trim();
      _managerInvitesFuture = _fetchManagerInvites(profile);
    });
  }

  /// Runs targeted queries in parallel with limit(25) to minimize Firestore reads.
  Future<_InviteDocList> _fetchManagerInvites(dynamic profile) async {
    final col = FirebaseFirestore.instance.collection('managerInvitations');
    final results = <String, QueryDocumentSnapshot>{};

    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final publicId = profile.publicId.toString().trim();
    final email = (profile.email ?? '').toString().trim();

    final queries = <Future<QuerySnapshot>>[
      if (uid.isNotEmpty)
        col.where('managerUserId', isEqualTo: uid).limit(25).get(),
      if (phone.isNotEmpty)
        col.where('phone', isEqualTo: phone).limit(25).get(),
      if (publicId.isNotEmpty)
        col.where('targetGrihoId', isEqualTo: publicId).limit(25).get(),
      if (email.isNotEmpty)
        col.where('targetEmail', isEqualTo: email).limit(25).get(),
    ];

    await Future.wait(
      queries.map((q) async {
        try {
          final snap = await q;
          for (final doc in snap.docs) {
            results[doc.id] = doc;
          }
        } catch (_) {}
      }),
    );

    final list = results.values.toList();
    list.sort((a, b) {
      final aT =
          (_inviteMap(a.data())['createdAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ??
          0;
      final bT =
          (_inviteMap(b.data())['createdAt'] as Timestamp?)
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
    if (_processing) {
      return;
    }
    setState(() => _processing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final data = _inviteMap(doc.data());
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

      if (!mounted) {
        return;
      }
      _refreshManagerInvites(profile);
      if (accept) {
        GrihoFeedback.showSuccess(
          context,
          'Invitation accepted! You now have manager access.',
        );
      } else {
        GrihoFeedback.showWarning(context, 'Invitation declined.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Failed to update invitation: $e');
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
    if (_processing) {
      return;
    }

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
                ? FilledButton.styleFrom(backgroundColor: GrihoColors.warning)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        currentlyActive
            ? '$managerName has been suspended.'
            : '$managerName access restored.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Error updating status: $e');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _revokeManagerAccess({
    required String invitationId,
    required String managerUserId,
    required String propertyId,
    required String managerName,
  }) async {
    if (_processing) {
      return;
    }

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

    if (confirmed != true || !mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }
      GrihoFeedback.showWarning(
        context,
        'Access permanently revoked for $managerName.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Failed to revoke access: $e');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Widget _buildInviteList(
    BuildContext context,
    ThemeData theme,
    dynamic profile,
    bool isOwnerView,
    _InviteDocList docs,
  ) {
    final visibleDocs = docs.where((doc) {
      final data = _inviteMap(doc.data());
      return (data['status'] ?? '').toString() != 'revoked';
    }).toList();

    if (visibleDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.user_octagon,
            title: isOwnerView
                ? 'No manager invitations sent yet'
                : 'No invitations found',
            subtitle: isOwnerView
                ? 'Assign a manager to help manage one of your buildings.'
                : 'When a property owner invites you via your Phone (${profile?.phoneNumber}) or Griho ID (${profile?.publicId}), it will appear here.',
            actionLabel: isOwnerView ? 'Invite Manager' : null,
            onAction: isOwnerView
                ? () => context.push(RouteNames.addManager)
                : null,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: visibleDocs.length,
      itemBuilder: (context, index) {
        final doc = visibleDocs[index];
        final data = _inviteMap(doc.data());
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
            ? GrihoColors.warning
            : isAccepted
            ? GrihoColors.emerald
            : isPending
            ? GrihoColors.warning
            : GrihoColors.error;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSuspended
                  ? GrihoColors.warning
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
                          ? Iconsax.pause_circle
                          : isAccepted
                          ? Iconsax.verify
                          : isPending
                          ? Iconsax.clock
                          : Iconsax.close_circle,
                      size: 20,
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
                      color: statusColor.withValues(alpha: 0.14),
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
                          isSuspended ? Iconsax.play : Iconsax.pause,
                          size: 16,
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
                        icon: const Icon(Iconsax.user_remove, size: 16),
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
                            if (!context.mounted) {
                              return;
                            }
                            GrihoFeedback.showInfo(
                              context,
                              'Invitation cancelled.',
                            );
                          },
                    icon: const Icon(
                      Iconsax.trash,
                      size: 16,
                      color: GrihoColors.error,
                    ),
                    label: const Text(
                      'Cancel Invite',
                      style: TextStyle(color: GrihoColors.error),
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

    return profileAsync.when(
      loading: () => const Scaffold(
        body: GrihoLoadingView(message: 'Loading invitations...'),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: err.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'Profile not found',
                  subtitle: 'Please sign in again.',
                ),
              ),
            ),
          );
        }
        final isOwnerView = profile.defaultDashboard == 'owner';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isOwnerView
                  ? 'Property Managers & Invites'
                  : 'My Manager Invitations',
            ),
          ),
          body: isOwnerView
              ? StreamBuilder<QuerySnapshot>(
                  stream: _getOwnerStream(profile.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const GrihoLoadingView(
                        message: 'Loading invitations...',
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GrihoStatusState(
                            icon: Iconsax.warning_2,
                            title: 'Error loading invitations',
                            subtitle: '${snapshot.error}',
                          ),
                        ),
                      );
                    }
                    return _buildInviteList(
                      context,
                      theme,
                      profile,
                      true,
                      snapshot.data?.docs ?? const [],
                    );
                  },
                )
              : RefreshIndicator(
                  onRefresh: () async => _refreshManagerInvites(profile),
                  child: FutureBuilder<_InviteDocList>(
                    future: _getManagerInvites(profile),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const GrihoLoadingView(
                          message: 'Loading invitations...',
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: GrihoStatusState(
                              icon: Iconsax.warning_2,
                              title: 'Error loading invitations',
                              subtitle: '${snapshot.error}',
                              actionLabel: 'Retry',
                              onAction: () => _refreshManagerInvites(profile),
                            ),
                          ),
                        );
                      }
                      return _buildInviteList(
                        context,
                        theme,
                        profile,
                        false,
                        snapshot.data ?? const [],
                      );
                    },
                  ),
                ),
          floatingActionButton: isOwnerView
              ? FloatingActionButton.extended(
                  onPressed: () => context.push(RouteNames.addManager),
                  icon: const Icon(Iconsax.user_add),
                  label: const Text('Invite Manager'),
                )
              : null,
        );
      },
    );
  }
}
