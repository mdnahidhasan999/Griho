// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
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

  Future<List<QueryDocumentSnapshot>> _fetchScopedManagerInvitations(
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

    return results.values.toList();
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
          'propertyName': data['propertyName'] ?? 'Assigned Building',
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openManagerIssuesSheet(
    BuildContext context,
    List<QueryDocumentSnapshot> issueDocs,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Building Maintenance Issues',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (issueDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No issues reported yet.')),
                ),
              for (final doc in issueDocs)
                Builder(
                  builder: (context) {
                    final d = doc.data() as Map<String, dynamic>? ?? {};
                    final title = (d['title'] ?? 'Issue').toString();
                    final desc = (d['description'] ?? '').toString();
                    final prop = (d['propertyName'] ?? '').toString();
                    final unit = (d['unitName'] ?? '').toString();
                    final cat = (d['category'] ?? 'general').toString();
                    final status = (d['status'] ?? 'open').toString();
                    final isDone = status == 'resolved';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            Text(
                              '$prop • $unit (${cat.toUpperCase()})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                desc,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (!isDone) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (status == 'open')
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          doc.reference.update({
                                            'status': 'in_progress',
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                        },
                                        child: const Text('In Progress'),
                                      ),
                                    ),
                                  if (status == 'open')
                                    const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: () {
                                        doc.reference.update({
                                          'status': 'resolved',
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                      },
                                      child: const Text('Mark Resolved'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
        centerTitle: false,
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
            tooltip: 'Activity & audit trail',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(RouteNames.activityLogs),
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
            stream: firestore
                .collection('managerAccess')
                .where('userId', isEqualTo: profile.uid)
                .snapshots(),
            builder: (context, accessSnap) {
              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchScopedManagerInvitations(profile),
                builder: (context, inviteSnapshot) {
                  final myInvites = inviteSnapshot.data ?? [];
                  final accessDocs = accessSnap.data?.docs ?? [];

                  final pendingInvites = myInvites.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['status'] ?? 'pending') == 'pending';
                  }).toList();

                  final activeAccessDocs = accessDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return (d['status'] ?? 'active') == 'active';
                  }).toList();

                  final suspendedAccessDocs = accessDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return (d['status'] ?? '') == 'suspended';
                  }).toList();

                  final managedPropertyIds = <String>{};
                  final propertyNames = <String, String>{};

                  for (final doc in activeAccessDocs) {
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

                  final issuesStream = propIdList.isEmpty
                      ? const Stream<QuerySnapshot>.empty()
                      : firestore
                            .collection('maintenanceRequests')
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
                              return StreamBuilder<QuerySnapshot>(
                                stream: issuesStream,
                                builder: (context, issuesSnap) {
                                  final myUnits = unitsSnap.data?.docs ?? [];
                                  final myTenants =
                                      tenantsSnap.data?.docs ?? [];
                                  final myBills = billsSnap.data?.docs ?? [];
                                  final myIssues = issuesSnap.data?.docs ?? [];

                                  final openIssuesCount = myIssues.where((d) {
                                    final m =
                                        d.data() as Map<String, dynamic>? ?? {};
                                    final s = (m['status'] ?? 'open')
                                        .toString();
                                    return s == 'open' || s == 'in_progress';
                                  }).length;

                                  final vacantUnitsCount = myUnits.where((doc) {
                                    final d =
                                        doc.data() as Map<String, dynamic>;
                                    return (d['status'] ?? 'available') ==
                                        'available';
                                  }).length;

                                  final occupiedUnitsCount =
                                      myUnits.length - vacantUnitsCount;

                                  final activeTenants = myTenants.where((doc) {
                                    final d =
                                        doc.data() as Map<String, dynamic>;
                                    return d['status'] == 'active';
                                  }).toList();

                                  var totalUnpaidDue = 0.0;
                                  var unpaidInvoicesCount = 0;

                                  for (final doc in myBills) {
                                    final d =
                                        doc.data() as Map<String, dynamic>;
                                    final status = (d['status'] ?? 'unpaid')
                                        .toString();
                                    if (status != 'paid' &&
                                        status != 'cancelled') {
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

                                  final gridItems = [
                                    _MgrAction(
                                      Icons.payments_outlined,
                                      'Payments',
                                      'Review & confirm',
                                      Colors.green,
                                      () => context.push(
                                        RouteNames.ownerPayments,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.build_circle_outlined,
                                      'Issues ($openIssuesCount)',
                                      'Tenant complaints',
                                      Colors.deepOrange,
                                      () => _openManagerIssuesSheet(
                                        context,
                                        myIssues,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.meeting_room_outlined,
                                      'Units',
                                      '$vacantUnitsCount vacant • $occupiedUnitsCount occupied',
                                      Colors.indigo,
                                      () => showManagerUnitsSheet(
                                        context: context,
                                        unitDocs: myUnits,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.groups_rounded,
                                      'Residents',
                                      '${activeTenants.length} active leases',
                                      Colors.teal,
                                      () => showManagerTenantsSheet(
                                        context: context,
                                        tenantDocs: myTenants,
                                        propertyNames: propertyNames,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.price_change_outlined,
                                      'Rent control',
                                      'Change rates',
                                      Colors.deepPurpleAccent,
                                      () => context.push(
                                        RouteNames.centralRentControl,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.receipt_long_rounded,
                                      'Billing rules',
                                      'Utilities & charges',
                                      Colors.amber.shade900,
                                      () => context.push(
                                        RouteNames.ownerBillingRules,
                                      ),
                                    ),
                                  ];

                                  return RefreshIndicator(
                                    onRefresh: () async {
                                      setState(() {});
                                    },
                                    child: ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        40,
                                      ),
                                      children: [
                                        // Unified Top Greeting Header
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _greeting(),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    profile.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: -0.5,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (profile.publicId.isNotEmpty)
                                              ActionChip(
                                                avatar: const Icon(
                                                  Icons.badge_outlined,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  profile.publicId,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: profile.publicId,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Griho ID copied.',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Open Issues Banner
                                        if (openIssuesCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: Material(
                                              color: theme
                                                  .colorScheme
                                                  .errorContainer,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              clipBehavior: Clip.antiAlias,
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.report_problem_rounded,
                                                  color: theme
                                                      .colorScheme
                                                      .onErrorContainer,
                                                ),
                                                title: Text(
                                                  openIssuesCount == 1
                                                      ? '1 tenant maintenance issue open'
                                                      : '$openIssuesCount tenant maintenance issues open',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: theme
                                                        .colorScheme
                                                        .onErrorContainer,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  'Tap to review & resolve',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .onErrorContainer,
                                                  ),
                                                ),
                                                trailing: Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: theme
                                                      .colorScheme
                                                      .onErrorContainer,
                                                ),
                                                onTap: () =>
                                                    _openManagerIssuesSheet(
                                                      context,
                                                      myIssues,
                                                    ),
                                              ),
                                            ),
                                          ),

                                        // Pending Invitations Banner
                                        if (pendingInvites.isNotEmpty)
                                          ...pendingInvites.map((inviteDoc) {
                                            final d =
                                                inviteDoc.data()
                                                    as Map<String, dynamic>;
                                            final propName =
                                                (d['propertyName'] ??
                                                        'Owner Property')
                                                    .toString();
                                            final ownerName =
                                                (d['ownerName'] ??
                                                        'Property Owner')
                                                    .toString();

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade700
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
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
                                                              : () =>
                                                                    _handleInvitation(
                                                                      inviteDoc,
                                                                      profile,
                                                                      false,
                                                                    ),
                                                          child: const Text(
                                                            'Decline',
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: FilledButton(
                                                          onPressed: _busy
                                                              ? null
                                                              : () =>
                                                                    _handleInvitation(
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

                                        if (suspendedAccessDocs.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .pause_circle_filled_rounded,
                                                  color: Colors.orange.shade900,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Access to ${suspendedAccessDocs.length} building(s) is temporarily suspended by the owner.',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .orange
                                                              .shade900,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        ManagerVaultCard(
                                          unpaidDue: totalUnpaidDue,
                                          activeTenantsCount:
                                              activeTenants.length,
                                          buildingsCount:
                                              managedPropertyIds.length,
                                          unpaidInvoicesCount:
                                              unpaidInvoicesCount,
                                        ),
                                        const SizedBox(height: 14),

                                        // Primary CTA
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                ),
                                                onPressed: () => context.push(
                                                  RouteNames.addTenant,
                                                ),
                                                icon: const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  size: 20,
                                                ),
                                                label: const Text(
                                                  'Add resident',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                ),
                                                onPressed: () => context.push(
                                                  RouteNames.ownerManagers,
                                                ),
                                                icon: const Icon(
                                                  Icons.mail_outline_rounded,
                                                  size: 20,
                                                ),
                                                label: const Text(
                                                  'Invitations',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),

                                        Text(
                                          'Quick actions',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Tenant-Style 2-Column Action Grid
                                        GridView.count(
                                          crossAxisCount: 2,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: 2.3,
                                          children: [
                                            for (final item in gridItems)
                                              Material(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  side: BorderSide(
                                                    color: theme
                                                        .colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: InkWell(
                                                  onTap: item.onTap,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                9,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: item.color
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  11,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            item.icon,
                                                            size: 20,
                                                            color: item.color,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                item.title,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                              Text(
                                                                item.subtitle,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
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

class _MgrAction {
  const _MgrAction(
    this.icon,
    this.title,
    this.subtitle,
    this.color,
    this.onTap,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}
