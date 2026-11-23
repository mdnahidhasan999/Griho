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
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/griho_home_chrome.dart';
import '../widgets/griho_home_components.dart';
import '../widgets/manager_portal_sheets.dart';
import '../widgets/shared_property_sheets.dart';

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends ConsumerState<ManagerHomeScreen> {
  bool _busy = false;
  Future<HomeDocList>? _invitesFuture;
  String? _cachedForUid;

  Stream<QuerySnapshot>? _accessStream;
  String? _accessStreamUid;

  String? _propStreamsKey;
  Stream<QuerySnapshot> _unitsStream = const Stream<QuerySnapshot>.empty();
  Stream<QuerySnapshot> _tenantsStream = const Stream<QuerySnapshot>.empty();
  Stream<QuerySnapshot> _billsStream = const Stream<QuerySnapshot>.empty();
  Stream<QuerySnapshot> _issuesStream = const Stream<QuerySnapshot>.empty();

  @override
  void initState() {
    super.initState();
    FcmNotificationService.instance.initialize(
      onNavigate: (route) {
        if (mounted) {
          context.push(route);
        }
      },
    );
  }

  Stream<QuerySnapshot> _getAccessStream(String uid) {
    if (_accessStream == null || _accessStreamUid != uid) {
      _accessStreamUid = uid;
      _accessStream = FirebaseFirestore.instance
          .collection('managerAccess')
          .where('userId', isEqualTo: uid)
          .snapshots();
    }
    return _accessStream!;
  }

  void _ensurePropertyStreams(List<String> propIdList) {
    final sorted = [...propIdList]..sort();
    final key = sorted.join(',');
    if (_propStreamsKey == key) {
      return;
    }
    _propStreamsKey = key;

    if (sorted.isEmpty) {
      _unitsStream = const Stream<QuerySnapshot>.empty();
      _tenantsStream = const Stream<QuerySnapshot>.empty();
      _billsStream = const Stream<QuerySnapshot>.empty();
      _issuesStream = const Stream<QuerySnapshot>.empty();
      return;
    }

    final db = FirebaseFirestore.instance;
    _unitsStream = db
        .collection('units')
        .where('propertyId', whereIn: sorted)
        .snapshots();
    _tenantsStream = db
        .collection('tenants')
        .where('propertyId', whereIn: sorted)
        .snapshots();
    _billsStream = db
        .collection('monthlyBills')
        .where('propertyId', whereIn: sorted)
        .snapshots();
    _issuesStream = db
        .collection('maintenanceRequests')
        .where('propertyId', whereIn: sorted)
        .snapshots();
  }

  Future<HomeDocList> _getOrFetchInvites(dynamic profile) {
    final uid = profile.uid.toString().trim();
    if (_invitesFuture == null || _cachedForUid != uid) {
      _cachedForUid = uid;
      _invitesFuture = _fetchPendingManagerInvitations(profile);
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = _fetchPendingManagerInvitations(profile);
    });
  }

  /// Queries only pending invitations to minimize Firestore reads.
  Future<HomeDocList> _fetchPendingManagerInvitations(dynamic profile) async {
    final col = FirebaseFirestore.instance.collection('managerInvitations');
    final results = <String, QueryDocumentSnapshot>{};

    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final publicId = profile.publicId.toString().trim();
    final email = (profile.email ?? '').toString().trim();

    final queries = <Future<QuerySnapshot>>[
      if (uid.isNotEmpty)
        col
            .where('managerUserId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (phone.isNotEmpty)
        col
            .where('phone', isEqualTo: phone)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (publicId.isNotEmpty)
        col
            .where('targetGrihoId', isEqualTo: publicId)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (email.isNotEmpty)
        col
            .where('targetEmail', isEqualTo: email)
            .where('status', isEqualTo: 'pending')
            .get(),
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

    return results.values.toList();
  }

  Future<void> _handleInvitation(
    QueryDocumentSnapshot doc,
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

      final firestore = FirebaseFirestore.instance;
      final data = homeAsMap(doc.data());
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

      if (!mounted) {
        return;
      }
      _refreshInvites(profile);
      if (accept) {
        GrihoFeedback.showSuccess(
          context,
          'Invitation accepted! Building linked to your console.',
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
        'Unable to process invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
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
    HomeDocList activeAccessDocs,
  ) {
    final props = activeAccessDocs
        .map((doc) {
          final d = homeAsMap(doc.data());
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

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: GrihoHomeAppBar(
        consoleLabel: 'Manager Console',
        extraActions: [
          IconButton(
            tooltip: 'Activity & audit trail',
            icon: const Icon(Iconsax.document_text),
            onPressed: () => context.push(RouteNames.activityLogs),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading console...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'Manager profile not found',
                  subtitle: 'Please sign in again.',
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _getAccessStream(profile.uid),
            builder: (context, accessSnap) {
              return FutureBuilder<HomeDocList>(
                future: _getOrFetchInvites(profile),
                builder: (context, inviteSnapshot) {
                  final pendingInvites =
                      inviteSnapshot.data ?? const <QueryDocumentSnapshot>[];
                  final accessDocs =
                      accessSnap.data?.docs ?? const <QueryDocumentSnapshot>[];

                  final activeAccessDocs = accessDocs.where((doc) {
                    final d = homeAsMap(doc.data());
                    return (d['status'] ?? 'active') == 'active';
                  }).toList();

                  final suspendedAccessDocs = accessDocs.where((doc) {
                    final d = homeAsMap(doc.data());
                    return (d['status'] ?? '') == 'suspended';
                  }).toList();

                  final managedPropertyIds = <String>{};
                  final propertyNames = <String, String>{};

                  for (final doc in activeAccessDocs) {
                    final d = homeAsMap(doc.data());
                    final pId = (d['propertyId'] ?? '').toString().trim();
                    final pName = (d['propertyName'] ?? '').toString().trim();
                    if (pId.isNotEmpty) {
                      managedPropertyIds.add(pId);
                      if (pName.isNotEmpty) {
                        propertyNames[pId] = pName;
                      }
                    }
                  }

                  final propIdList = managedPropertyIds.take(10).toList();
                  _ensurePropertyStreams(propIdList);

                  return StreamBuilder<QuerySnapshot>(
                    stream: _unitsStream,
                    builder: (context, unitsSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _tenantsStream,
                        builder: (context, tenantsSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: _billsStream,
                            builder: (context, billsSnap) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: _issuesStream,
                                builder: (context, issuesSnap) {
                                  final myUnits =
                                      unitsSnap.data?.docs ??
                                      const <QueryDocumentSnapshot>[];
                                  final myTenants =
                                      tenantsSnap.data?.docs ??
                                      const <QueryDocumentSnapshot>[];
                                  final myBills =
                                      billsSnap.data?.docs ??
                                      const <QueryDocumentSnapshot>[];
                                  final myIssues =
                                      issuesSnap.data?.docs ??
                                      const <QueryDocumentSnapshot>[];

                                  final openIssuesCount = myIssues.where((d) {
                                    final m = homeAsMap(d.data());
                                    final s = (m['status'] ?? 'open')
                                        .toString();
                                    return s == 'open' || s == 'in_progress';
                                  }).length;

                                  final vacantUnitsCount = myUnits.where((doc) {
                                    final d = homeAsMap(doc.data());
                                    return (d['status'] ?? 'available') ==
                                        'available';
                                  }).length;

                                  final occupiedUnitsCount =
                                      myUnits.length - vacantUnitsCount;

                                  final activeTenants = myTenants.where((doc) {
                                    final d = homeAsMap(doc.data());
                                    return d['status'] == 'active';
                                  }).toList();

                                  var totalUnpaidDue = 0.0;
                                  var unpaidInvoicesCount = 0;

                                  for (final doc in myBills) {
                                    final d = homeAsMap(doc.data());
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

                                  final dueText =
                                      totalUnpaidDue ==
                                          totalUnpaidDue.roundToDouble()
                                      ? totalUnpaidDue.toStringAsFixed(0)
                                      : totalUnpaidDue.toStringAsFixed(2);

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
                                        for (final inviteDoc in pendingInvites)
                                          Builder(
                                            builder: (context) {
                                              final d = homeAsMap(
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
                                              return GrihoPendingInviteBanner(
                                                title:
                                                    'New Manager Assignment: $propName',
                                                subtitle:
                                                    'Invited by $ownerName',
                                                acceptLabel: 'Accept Role',
                                                busy: _busy,
                                                onAccept: () =>
                                                    _handleInvitation(
                                                      inviteDoc,
                                                      profile,
                                                      true,
                                                    ),
                                                onDecline: () =>
                                                    _handleInvitation(
                                                      inviteDoc,
                                                      profile,
                                                      false,
                                                    ),
                                              );
                                            },
                                          ),
                                        if (suspendedAccessDocs.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: GrihoColors.warning
                                                  .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: GrihoColors.warning,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Iconsax.pause_circle,
                                                  color: GrihoColors.warning,
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
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        GrihoHeroCard(
                                          eyebrow: 'UNPAID DUES ACROSS UNITS',
                                          eyebrowIcon: Iconsax.wallet_3,
                                          headline: '৳ $dueText',
                                          metrics: [
                                            GrihoHeroMetric(
                                              label: 'Buildings',
                                              value:
                                                  '${managedPropertyIds.length}',
                                            ),
                                            GrihoHeroMetric(
                                              label: 'Residents',
                                              value: '${activeTenants.length}',
                                            ),
                                            GrihoHeroMetric(
                                              label: 'Unpaid bills',
                                              value: '$unpaidInvoicesCount',
                                              highlight:
                                                  unpaidInvoicesCount > 0,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GrihoPrimaryButton(
                                                label: 'Add resident',
                                                icon: Iconsax.user_add,
                                                onPressed: () => context.push(
                                                  RouteNames.addTenant,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: GrihoSecondaryButton(
                                                label: 'Invitations',
                                                icon: Iconsax.sms,
                                                onPressed: () => context.push(
                                                  RouteNames.ownerManagers,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),
                                        const GrihoSectionHeader(
                                          'Quick actions',
                                        ),
                                        const SizedBox(height: 10),
                                        GrihoQuickActionGrid(
                                          items: [
                                            GrihoQuickActionItem(
                                              icon: Iconsax.wallet_check,
                                              title: 'Payments',
                                              subtitle: 'Review & confirm',
                                              color: GrihoColors.emerald,
                                              onTap: () => context.push(
                                                RouteNames.ownerPayments,
                                              ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.setting_2,
                                              title:
                                                  'Issues ($openIssuesCount)',
                                              subtitle: 'Tenant complaints',
                                              color: Colors.deepOrange,
                                              onTap: () =>
                                                  _openManagerIssuesSheet(
                                                    context,
                                                    propIdList,
                                                    profile.name,
                                                  ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.notification_bing,
                                              title: 'Notices',
                                              subtitle: 'Post & manage',
                                              color: GrihoColors.warning,
                                              onTap: () =>
                                                  _openManagerNoticesSheet(
                                                    context,
                                                    profile.uid,
                                                    profile.name,
                                                    activeAccessDocs,
                                                  ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.buildings_2,
                                              title: 'Units',
                                              subtitle:
                                                  '$vacantUnitsCount vacant • $occupiedUnitsCount occupied',
                                              color: Colors.indigo,
                                              onTap: () =>
                                                  showManagerUnitsSheet(
                                                    context: context,
                                                    unitDocs: myUnits,
                                                    propertyNames:
                                                        propertyNames,
                                                  ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.people,
                                              title: 'Residents',
                                              subtitle:
                                                  '${activeTenants.length} active leases',
                                              color: Colors.teal,
                                              onTap: () =>
                                                  showManagerTenantsSheet(
                                                    context: context,
                                                    tenantDocs: myTenants,
                                                    propertyNames:
                                                        propertyNames,
                                                  ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.money_change,
                                              title: 'Rent control',
                                              subtitle: 'Change rates',
                                              color: Colors.deepPurpleAccent,
                                              onTap: () => context.push(
                                                RouteNames.centralRentControl,
                                              ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.receipt_item,
                                              title: 'Billing rules',
                                              subtitle: 'Utilities & charges',
                                              color: Colors.brown,
                                              onTap: () => context.push(
                                                RouteNames.ownerBillingRules,
                                              ),
                                            ),
                                            GrihoQuickActionItem(
                                              icon: Iconsax.document_text,
                                              title: 'Audit trail',
                                              subtitle: 'Activity logs',
                                              color: Colors.blueGrey,
                                              onTap: () => context.push(
                                                RouteNames.activityLogs,
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
