import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  bool _matchesManager(Map<String, dynamic> data, dynamic profile) {
    if (profile == null) return false;
    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final digitsOnlyPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final localPhone = digitsOnlyPhone.startsWith('880')
        ? digitsOnlyPhone.substring(2)
        : digitsOnlyPhone;
    final publicId = profile.publicId.toString().trim().toUpperCase();
    final email = (profile.email ?? '').toString().trim().toLowerCase();

    final invIdentifier = (data['identifier'] ?? '').toString().trim();
    final invPhone = (data['phone'] ?? '').toString().trim();
    final invRawPhone = (data['rawPhone'] ?? '').toString().trim();
    final invGrihoId = (data['targetGrihoId'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final invEmail = (data['targetEmail'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final invUserId = (data['targetUserId'] ?? '').toString().trim();

    return (invUserId.isNotEmpty && invUserId == uid) ||
        (publicId.isNotEmpty &&
            (invGrihoId == publicId ||
                invIdentifier.toUpperCase() == publicId)) ||
        (email.isNotEmpty &&
            (invEmail == email || invIdentifier.toLowerCase() == email)) ||
        (phone.isNotEmpty &&
            (invPhone == phone ||
                invIdentifier == phone ||
                invIdentifier == localPhone ||
                invRawPhone == localPhone ||
                invRawPhone == digitsOnlyPhone));
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
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation accepted! You now have manager access.'
                : 'Invitation declined.',
          ),
          backgroundColor: accept ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
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
        final isOwnerView = profile?.defaultDashboard == 'owner';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isOwnerView
                  ? 'Property Managers & Invites'
                  : 'My Manager Invitations',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('managerInvitations')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading invitations: ${snapshot.error}'),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (isOwnerView) {
                  final ownerId = (data['ownerId'] ?? '').toString().trim();
                  return ownerId.isEmpty || ownerId == profile?.uid;
                } else {
                  return _matchesManager(data, profile);
                }
              }).toList();

              if (docs.isEmpty) {
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
                            onPressed: () =>
                                context.push(RouteNames.addManager),
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
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Manager';
                  final identifier = data['identifier'] ?? '';
                  final propertyName =
                      (data['propertyName'] ?? 'All Properties').toString();
                  final status = (data['status'] ?? 'pending').toString();
                  final isPending = status == 'pending';
                  final isAccepted = status == 'accepted';

                  final statusColor = isAccepted
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
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withValues(
                                alpha: 0.14,
                              ),
                              child: Icon(
                                isAccepted
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
                                    name.toString(),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Building: $propertyName',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
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
                                status.toUpperCase(),
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
                                      : () => _respondToInvitation(
                                          doc,
                                          profile,
                                          false,
                                        ),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _processing
                                      ? null
                                      : () => _respondToInvitation(
                                          doc,
                                          profile,
                                          true,
                                        ),
                                  child: const Text('Accept & Manage'),
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
                              onPressed: () async {
                                await doc.reference.delete();
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Revoke Invite',
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
