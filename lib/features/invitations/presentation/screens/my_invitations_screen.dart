// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/recipient_invitations_provider.dart';
import '../providers/work_invitations_providers.dart';

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
      final authUser = FirebaseAuth.instance.currentUser;
      await authUser?.reload();
      if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
        throw StateError(
          'Please verify your email address before responding to an invitation.',
        );
      }

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
          content: Text(
            'Could not update invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
          ),
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
    final workAsync = ref.watch(pendingWorkInvitationsProvider);
    final leaseAsync = ref.watch(recipientPendingInvitationsProvider);

    final isLoading =
        (workAsync.isLoading && !workAsync.hasValue) ||
        (leaseAsync.isLoading && !leaseAsync.hasValue);

    final workList = workAsync.value ?? const <WorkInvitation>[];
    final leaseList = leaseAsync.value ?? const <TenantInvitation>[];

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Invitations',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingWorkInvitationsProvider);
          ref.invalidate(recipientInvitationsProvider);
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 105),
                children: [
                  Text(
                    'All residency offers and team assignments sent to your account appear here across every role.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (leaseList.isEmpty && workList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 52,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No pending invitations',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Tenancy / Lease Offers
                  if (leaseList.isNotEmpty) ...[
                    Text(
                      'Tenancy & Unit Offers (${leaseList.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final lease in leaseList)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
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
                                      Icons.home_work_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lease.propertyName ??
                                              'Residency Offer',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          'Unit ${lease.unitNumber ?? lease.unitName ?? ''} • ৳${lease.rentAmount.toStringAsFixed(0)} / mo',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => context.push(
                                    RouteNames.tenantInvitationPath(
                                      lease.token,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Review & Respond'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],

                  // 2. Team & Work Offers
                  if (workList.isNotEmpty) ...[
                    Text(
                      'Team & Work Offers (${workList.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final inv in workList)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.secondaryContainer,
                                    child: Icon(
                                      _icon(inv.role),
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                ],
              ),
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.invites,
      ),
    );
  }
}
