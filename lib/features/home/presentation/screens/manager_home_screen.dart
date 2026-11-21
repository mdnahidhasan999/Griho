// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/griho_home_chrome.dart';
import '../widgets/manager_portal_sheets.dart';
import '../widgets/shared_property_sheets.dart';

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends ConsumerState<ManagerHomeScreen> {
  bool _busy = false;
  Future<List<QueryDocumentSnapshot>>? _invitesFuture;
  String? _cachedForUid;

  @override
  void initState() {
    super.initState();
    FcmNotificationService.instance.initialize(
      onNavigate: (route) {
        if (mounted) context.push(route);
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _getOrFetchInvites(dynamic profile) {
    final uid = profile.uid.toString().trim();
    if (_invitesFuture == null || _cachedForUid != uid) {
      _cachedForUid = uid;
      _invitesFuture = _fetchScopedManagerInvitations(profile);
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = _fetchScopedManagerInvitations(profile);
    });
  }

  Future<List<QueryDocumentSnapshot>> _fetchScopedManagerInvitations(
    dynamic profile,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('managerInvitations');
    final results = <String, QueryDocumentSnapshot>{};

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

    final snapshots = await Future.wait(
      queries.map((q) => q.catchError((_) => throw StateError('skip'))),
      eagerError: false,
    ).catchError((_) => const <QuerySnapshot>[]);

    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        results[doc.id] = doc;
      }
    }

    if (results.isEmpty && queries.isNotEmpty) {
      for (final future in queries) {
        try {
          final snap = await future;
          for (final doc in snap.docs) {
            results[doc.id] = doc;
          }
        } catch (_) {}
      }
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
      final authUser = FirebaseAuth.instance.currentUser;
      await authUser?.reload();
      if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
        throw StateError(
          'Please verify your email address before responding to an invitation.',
        );
      }

      final firestore = FirebaseFirestore.instance;
      final data = asJsonMap(doc.data());
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
      _refreshInvites(profile);
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
          content: Text(
            'Unable to process invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
          ),
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

  void _openManagerIssuesSheet(
    BuildContext context,
    List<String> propertyIds,
    String managerName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BuildingMaintenanceSheet(
        filterField: 'propertyId',
        filterValues: propertyIds,
        actorName: managerName,
        actorRole: 'manager',
        title: 'Building Maintenance Issues',
      ),
    );
  }

  void _openManagerNoticesSheet(
    BuildContext context,
    String uid,
    String userName,
    List<QueryDocumentSnapshot> activeAccessDocs,
  ) {
    final props = activeAccessDocs
        .map((doc) {
          final d = asJsonMap(doc.data());
          return NoticePropertyOption(
            id: (d['propertyId'] ?? '').toString(),
            name: (d['propertyName'] ?? 'Building').toString(),
            ownerId: (d['ownerId'] ?? '').toString(),
          );
        })
        .where((p) => p.id.isNotEmpty)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BuildingNoticesSheet(
        actorUid: uid,
        actorName: userName,
        actorRole: 'manager',
        properties: props,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: GrihoHomeAppBar(
        consoleLabel: 'Manager Console',
        extraActions: [
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
                future: _getOrFetchInvites(profile),
                builder: (context, inviteSnapshot) {
                  final myInvites = inviteSnapshot.data ?? [];
                  final accessDocs = accessSnap.data?.docs ?? [];

                  final pendingInvites = myInvites.where((doc) {
                    final data = asJsonMap(doc.data());
                    return (data['status'] ?? 'pending') == 'pending';
                  }).toList();

                  final activeAccessDocs = accessDocs.where((doc) {
                    final d = asJsonMap(doc.data());
                    return (d['status'] ?? 'active') == 'active';
                  }).toList();

                  final suspendedAccessDocs = accessDocs.where((doc) {
                    final d = asJsonMap(doc.data());
                    return (d['status'] ?? '') == 'suspended';
                  }).toList();

                  final managedPropertyIds = <String>{};
                  final propertyNames = <String, String>{};

                  for (final doc in activeAccessDocs) {
                    final d = asJsonMap(doc.data());
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
                                    final m = asJsonMap(d.data());
                                    final s = (m['status'] ?? 'open')
                                        .toString();
                                    return s == 'open' || s == 'in_progress';
                                  }).length;

                                  final vacantUnitsCount = myUnits.where((doc) {
                                    final d = asJsonMap(doc.data());
                                    return (d['status'] ?? 'available') ==
                                        'available';
                                  }).length;

                                  final occupiedUnitsCount =
                                      myUnits.length - vacantUnitsCount;

                                  final activeTenants = myTenants.where((doc) {
                                    final d = asJsonMap(doc.data());
                                    return d['status'] == 'active';
                                  }).toList();

                                  var totalUnpaidDue = 0.0;
                                  var unpaidInvoicesCount = 0;

                                  for (final doc in myBills) {
                                    final d = asJsonMap(doc.data());
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
                                        propIdList,
                                        profile.name,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.campaign_outlined,
                                      'Notices',
                                      'Post & manage',
                                      Colors.amber.shade800,
                                      () => _openManagerNoticesSheet(
                                        context,
                                        profile.uid,
                                        profile.name,
                                        activeAccessDocs,
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
                                      Colors.brown,
                                      () => context.push(
                                        RouteNames.ownerBillingRules,
                                      ),
                                    ),
                                    _MgrAction(
                                      Icons.history_edu_rounded,
                                      'Audit trail',
                                      'Activity logs',
                                      Colors.blueGrey,
                                      () =>
                                          context.push(RouteNames.activityLogs),
                                    ),
                                  ];

                                  return RefreshIndicator(
                                    onRefresh: () async {
                                      _refreshInvites(profile);
                                    },
                                    child: ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        105,
                                      ),
                                      children: [
                                        GrihoHomeTopHeader(
                                          name: profile.name,
                                          publicId: profile.publicId,
                                        ),
                                        const SizedBox(height: 16),

                                        OpenIssuesBanner(
                                          filterField: 'propertyId',
                                          filterValues: propIdList,
                                          subtitle: 'Tap to review & resolve',
                                          onTap: () => _openManagerIssuesSheet(
                                            context,
                                            propIdList,
                                            profile.name,
                                          ),
                                        ),

                                        if (pendingInvites.isNotEmpty)
                                          ...pendingInvites.map((inviteDoc) {
                                            final d = asJsonMap(
                                              inviteDoc.data(),
                                            );
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
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
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
