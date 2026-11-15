import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../providers/work_invitations_providers.dart';

/// One place to receive Manager / Caretaker / Electrician invitations, whatever
/// console the user is currently in (e.g. a Tenant who is invited as Caretaker).
class MyInvitationsScreen extends ConsumerStatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  ConsumerState<MyInvitationsScreen> createState() =>
      _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends ConsumerState<MyInvitationsScreen> {
  bool _busy = false;

  IconData _icon(String role) {
    switch (role) {
      case 'manager':
        return Icons.admin_panel_settings_rounded;
      case 'electrician':
        return Icons.bolt_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  String _route(String role) {
    switch (role) {
      case 'manager':
        return RouteNames.managerHome;
      case 'electrician':
        return RouteNames.electricianHome;
      default:
        return RouteNames.caretakerHome;
    }
  }

  Future<void> _respond(
    WorkInvitation inv,
    dynamic profile,
    bool accept,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final data = inv.data;
      final propertyId = (data['propertyId'] ?? '').toString().trim();
      final ownerId = (data['ownerId'] ?? '').toString().trim();
      final batch = db.batch();

      if (inv.isManager) {
        batch.update(inv.doc.reference, {
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
          batch.set(
            db.collection('managerAccess').doc('${profile.uid}_$propertyId'),
            {
              'userId': profile.uid,
              'managerName': profile.name,
              'managerGrihoId': profile.publicId,
              'managerPhone': profile.phoneNumber,
              'ownerId': ownerId,
              'propertyId': propertyId,
              'propertyName': data['propertyName'] ?? 'Property',
              'propertyCode': data['propertyCode'] ?? '',
              'invitationId': inv.doc.id,
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      } else {
        batch.update(inv.doc.reference, {
          'status': accept ? 'accepted' : 'rejected',
          'accessStatus': accept ? 'active' : 'rejected',
          'staffUserId': profile.uid,
          'staffName': profile.name,
          'staffGrihoId': profile.publicId,
          'staffPhone': profile.phoneNumber,
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (accept && propertyId.isNotEmpty) {
          batch.set(
            db
                .collection('staffAccess')
                .doc('${profile.uid}_${propertyId}_${inv.role}'),
            {
              'userId': profile.uid,
              'staffName': profile.name,
              'staffGrihoId': profile.publicId,
              'staffPhone': profile.phoneNumber,
              'staffRole': inv.role,
              'ownerId': ownerId,
              'propertyId': propertyId,
              'propertyName': data['propertyName'] ?? 'Assigned Building',
              'propertyCode': data['propertyCode'] ?? '',
              'invitationId': inv.doc.id,
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (accept) {
        final roles = List<String>.from(profile.availableRoles ?? const []);
        if (!roles.contains(inv.role)) {
          // Keep the user's current default console; only the roster grows.
          batch.update(db.collection('users').doc(profile.uid), {
            'availableRoles': FieldValue.arrayUnion([inv.role]),
            if (roles.isEmpty) 'defaultDashboard': inv.role,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      AuthRouteGuard.clearAccessCache();
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(pendingWorkInvitationsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: accept ? Colors.green : Colors.orange,
          content: Text(
            accept
                ? 'You are now ${WorkInvitation.roleLabel(inv.role)} of ${inv.propertyName}.'
                : 'Invitation declined.',
          ),
          action: accept
              ? SnackBarAction(
                  label: 'OPEN',
                  textColor: Colors.white,
                  onPressed: () => context.go(_route(inv.role)),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update invitation: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final async = ref.watch(pendingWorkInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Work invitations')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingWorkInvitationsProvider);
          await ref.read(pendingWorkInvitationsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load: $e'),
              ),
            ],
          ),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Invitations from property owners to work as manager, caretaker or electrician. '
                'They appear here no matter which account you are using.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No pending invitations',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              for (final inv in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(
                                _icon(inv.role),
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    WorkInvitation.roleLabel(inv.role),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${inv.propertyName} • from ${inv.ownerName}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: (_busy || profile == null)
                                    ? null
                                    : () => _respond(inv, profile, false),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: (_busy || profile == null)
                                    ? null
                                    : () => _respond(inv, profile, true),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
