// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
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
        return Iconsax.user_octagon;
      case 'electrician':
        return Iconsax.flash_1;
      default:
        return Iconsax.setting_2;
    }
  }

  Future<void> _respond(
    WorkInvitation inv,
    dynamic profile,
    bool accept,
  ) async {
    if (_busy) {
      return;
    }
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

      if (!mounted) {
        return;
      }
      if (accept) {
        GrihoFeedback.showSuccess(
          context,
          'You are now ${WorkInvitation.roleLabel(inv.role)} of${inv.propertyName}.',
        );
      } else {
        GrihoFeedback.showWarning(context, 'Invitation declined.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        'Could not update invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
      appBar: AppBar(title: const Text('Invitations')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingWorkInvitationsProvider);
          ref.invalidate(recipientInvitationsProvider);
        },
        child: isLoading
            ? const GrihoLoadingView(message: 'Loading invitations...')
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: GrihoStatusState(
                        icon: Iconsax.sms,
                        title: 'No pending invitations',
                        subtitle:
                            'New residency or team invitations will appear here automatically.',
                      ),
                    ),
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
                                      Iconsax.buildings_2,
                                      size: 20,
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
                              GrihoPrimaryButton(
                                label: 'Review & Respond',
                                icon: Iconsax.arrow_right_3,
                                onPressed: () => context.push(
                                  RouteNames.tenantInvitationPath(lease.token),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
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
                                      size: 20,
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
