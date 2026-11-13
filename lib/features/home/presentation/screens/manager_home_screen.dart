// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/manager_portal_sheets.dart';

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends ConsumerState<ManagerHomeScreen> {
  bool _busy = false;

  bool _isInviteForUser(Map<String, dynamic> data, dynamic profile) {
    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    final localPhone = digitsOnly.startsWith('880')
        ? digitsOnly.substring(2)
        : digitsOnly;
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
    final managerUid = (data['managerUserId'] ?? '').toString().trim();

    return (managerUid.isNotEmpty && managerUid == uid) ||
        (invUserId.isNotEmpty && invUserId == uid) ||
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
                invRawPhone == digitsOnly));
  }

  Future<void> _handleInvitation(
    QueryDocumentSnapshot doc,
    dynamic profile,
    bool accept,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

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
          'propertyName': data['propertyName'] ?? 'Assigned Building',
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
                ? 'Invitation accepted! Building linked to your console.'
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
          content: Text('Unable to process invitation: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
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
    final profileAsync = ref.watch(currentUserProfileProvider);
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Griho',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Manager Console',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Invitations',
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () => context.push(RouteNames.ownerManagers),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading profile: $error')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Manager profile not found.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('managerInvitations').snapshots(),
            builder: (context, inviteSnapshot) {
              final allInviteDocs = inviteSnapshot.data?.docs ?? [];
              final myInvites = allInviteDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _isInviteForUser(data, profile);
              }).toList();

              final pendingInvites = myInvites.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? 'pending') == 'pending';
              }).toList();

              final acceptedInvites = myInvites.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'accepted';
              }).toList();

              final managedPropertyIds = <String>{};
              final propertyNames = <String, String>{};

              for (final doc in acceptedInvites) {
                final d = doc.data() as Map<String, dynamic>;
                final pId = (d['propertyId'] ?? '').toString().trim();
                final pName = (d['propertyName'] ?? '').toString().trim();
                if (pId.isNotEmpty) {
                  managedPropertyIds.add(pId);
                  if (pName.isNotEmpty) propertyNames[pId] = pName;
                }
              }

              final propIdList = managedPropertyIds.take(10).toList();

              final unitsStream = propIdList.isEmpty
                  ? const Stream<QuerySnapshot>.empty()
                  : firestore
                        .collection('units')
                        .where('propertyId', whereIn: propIdList)
                        .snapshots();

              final tenantsStream = propIdList.isEmpty
                  ? const Stream<QuerySnapshot>.empty()
                  : firestore
                        .collection('tenants')
                        .where('propertyId', whereIn: propIdList)
                        .snapshots();

              final billsStream = propIdList.isEmpty
                  ? const Stream<QuerySnapshot>.empty()
                  : firestore
                        .collection('monthlyBills')
                        .where('propertyId', whereIn: propIdList)
                        .snapshots();

              return StreamBuilder<QuerySnapshot>(
                stream: unitsStream,
                builder: (context, unitsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: tenantsStream,
                    builder: (context, tenantsSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: billsStream,
                        builder: (context, billsSnap) {
                          final myUnits = unitsSnap.data?.docs ?? [];
                          final myTenants = tenantsSnap.data?.docs ?? [];
                          final myBills = billsSnap.data?.docs ?? [];

                          final vacantUnitsCount = myUnits.where((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return (d['status'] ?? 'available') == 'available';
                          }).length;

                          final occupiedUnitsCount =
                              myUnits.length - vacantUnitsCount;

                          final activeTenants = myTenants.where((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return d['status'] == 'active';
                          }).toList();

                          var totalUnpaidDue = 0.0;
                          var unpaidInvoicesCount = 0;

                          for (final doc in myBills) {
                            final d = doc.data() as Map<String, dynamic>;
                            final status = (d['status'] ?? 'unpaid').toString();
                            if (status != 'paid' && status != 'cancelled') {
                              final amount = (d['amount'] is num)
                                  ? (d['amount'] as num).toDouble()
                                  : 0.0;
                              final paid = (d['paidAmount'] is num)
                                  ? (d['paidAmount'] as num).toDouble()
                                  : 0.0;
                              final rem = amount - paid;
                              if (rem > 0) {
                                totalUnpaidDue += rem;
                                unpaidInvoicesCount++;
                              }
                            }
                          }

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            children: [
                              ManagerExecutiveHeader(
                                name: profile.name,
                                publicId: profile.publicId,
                              ),
                              const SizedBox(height: 18),

                              // Pending Invitations Banner
                              if (pendingInvites.isNotEmpty)
                                ...pendingInvites.map((inviteDoc) {
                                  final d =
                                      inviteDoc.data() as Map<String, dynamic>;
                                  final propName =
                                      (d['propertyName'] ?? 'Owner Property')
                                          .toString();
                                  final ownerName =
                                      (d['ownerName'] ?? 'Property Owner')
                                          .toString();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.amber.shade800,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'New Manager Assignment: $propName',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Invited by $ownerName'),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _handleInvitation(
                                                        inviteDoc,
                                                        profile,
                                                        false,
                                                      ),
                                                child: const Text('Decline'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _handleInvitation(
                                                        inviteDoc,
                                                        profile,
                                                        true,
                                                      ),
                                                child: const Text(
                                                  'Accept Role',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                              ManagerVaultCard(
                                unpaidDue: totalUnpaidDue,
                                activeTenantsCount: activeTenants.length,
                                buildingsCount: managedPropertyIds.isNotEmpty
                                    ? managedPropertyIds.length
                                    : acceptedInvites.length,
                                unpaidInvoicesCount: unpaidInvoicesCount,
                              ),
                              const SizedBox(height: 16),

                              // Pulse Row
                              Row(
                                children: [
                                  Expanded(
                                    child: ManagerPulseTile(
                                      title: 'Vacant Units',
                                      value: '$vacantUnitsCount',
                                      icon: Icons.meeting_room_rounded,
                                      color: Colors.green,
                                      onTap: () => showManagerUnitsSheet(
                                        context: context,
                                        unitDocs: myUnits,
                                        propertyNames: propertyNames,
                                        initialFilter: 'available',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ManagerPulseTile(
                                      title: 'Occupied',
                                      value: '$occupiedUnitsCount',
                                      icon: Icons.door_front_door_rounded,
                                      color: Colors.indigo,
                                      onTap: () => showManagerUnitsSheet(
                                        context: context,
                                        unitDocs: myUnits,
                                        propertyNames: propertyNames,
                                        initialFilter: 'occupied',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ManagerPulseTile(
                                      title: 'Residents',
                                      value: '${activeTenants.length}',
                                      icon: Icons.groups_rounded,
                                      color: Colors.teal,
                                      onTap: () => showManagerTenantsSheet(
                                        context: context,
                                        tenantDocs: myTenants,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Text(
                                'Command Center',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Direct property administration, rent & utility billing actions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Register New Resident Button
                              Material(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () =>
                                      context.push(RouteNames.addTenant),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Register New Resident',
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Assign vacant units and dispatch tenancy invites',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 4 Sub-Action Shortcuts (Payments, Rent Control, Billing Rules, Units)
                              Row(
                                children: [
                                  Expanded(
                                    child: ManagerSubActionTile(
                                      icon: Icons.payments_outlined,
                                      title: 'Payments',
                                      color: Colors.blueAccent,
                                      onTap: () => context.push(
                                        RouteNames.ownerPayments,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ManagerSubActionTile(
                                      icon: Icons.price_change_outlined,
                                      title: 'Rent Control',
                                      color: Colors.deepPurpleAccent,
                                      onTap: () => context.push(
                                        RouteNames.centralRentControl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ManagerSubActionTile(
                                      icon: Icons.receipt_long_rounded,
                                      title: 'Billing Rules',
                                      color: Colors.amber.shade900,
                                      onTap: () => context.push(
                                        RouteNames.ownerBillingRules,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ManagerSubActionTile(
                                      icon: Icons.meeting_room_outlined,
                                      title: 'Units',
                                      color: Colors.green,
                                      onTap: () => showManagerUnitsSheet(
                                        context: context,
                                        unitDocs: myUnits,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Management Hub
                              Material(
                                color: theme.colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        Icons.meeting_room_outlined,
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: const Text(
                                        'Units & Vacancy Explorer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$vacantUnitsCount Vacant • $occupiedUnitsCount Occupied units',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: () => showManagerUnitsSheet(
                                        context: context,
                                        unitDocs: myUnits,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    ListTile(
                                      leading: Icon(
                                        Icons.badge_outlined,
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: const Text(
                                        'Residents & Leases Directory',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${activeTenants.length} Active leases • Manage agreements & move-outs',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: () => showManagerTenantsSheet(
                                        context: context,
                                        tenantDocs: myTenants,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    ListTile(
                                      leading: Icon(
                                        Icons.price_change_outlined,
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: const Text(
                                        'Rent & Tariff Control',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Adjust rent across building, floor, or unit & generate invoices',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: () => context.push(
                                        RouteNames.centralRentControl,
                                      ),
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    ListTile(
                                      leading: Icon(
                                        Icons.tune_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: const Text(
                                        'Automated Billing & Invoicing Engine',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Create utility rules, generate monthly bills & cancel unpaid errors',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: () => context.push(
                                        RouteNames.ownerBillingRules,
                                      ),
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    ListTile(
                                      leading: Icon(
                                        Icons.mail_outline_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: const Text(
                                        'Manager Invitations & Access',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${pendingInvites.length} Pending • ${acceptedInvites.length} Active assignments',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: () => context.push(
                                        RouteNames.ownerManagers,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.managerHome),
        onMoreTap: () => context.push(RouteNames.more),
      ),
    );
  }
}
