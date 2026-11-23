// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/griho_home_chrome.dart';
import '../widgets/griho_home_components.dart';

class ElectricianHomeScreen extends ConsumerStatefulWidget {
  const ElectricianHomeScreen({super.key});

  @override
  ConsumerState<ElectricianHomeScreen> createState() =>
      _ElectricianHomeScreenState();
}

class _ElectricianHomeScreenState extends ConsumerState<ElectricianHomeScreen> {
  bool _busy = false;
  String? _selectedPropertyId;

  Future<HomeDocList>? _invitesFuture;
  String? _cachedForUid;

  Stream<QuerySnapshot>? _accessStream;
  String? _accessStreamUid;

  String? _activeStreamsPropId;
  Stream<QuerySnapshot> _metersStream = const Stream<QuerySnapshot>.empty();
  Stream<QuerySnapshot> _repairsStream = const Stream<QuerySnapshot>.empty();

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
          .collection('staffAccess')
          .where('userId', isEqualTo: uid)
          .where('staffRole', isEqualTo: 'electrician')
          .snapshots();
    }
    return _accessStream!;
  }

  void _ensurePropertyStreams(String propertyId) {
    if (_activeStreamsPropId == propertyId) {
      return;
    }
    _activeStreamsPropId = propertyId;
    final db = FirebaseFirestore.instance;
    _metersStream = db
        .collection('meterReadings')
        .where('propertyId', isEqualTo: propertyId)
        .limit(50)
        .snapshots();
    _repairsStream = db
        .collection('maintenanceRequests')
        .where('propertyId', isEqualTo: propertyId)
        .limit(50)
        .snapshots();
  }

  Future<HomeDocList> _getOrFetchInvites(dynamic profile) {
    final uid = profile.uid.toString().trim();
    if (_invitesFuture == null || _cachedForUid != uid) {
      _cachedForUid = uid;
      _invitesFuture = GrihoStaffInviteService.fetchPendingStaffInvites(
        profile: profile,
        staffRole: 'electrician',
      );
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = GrihoStaffInviteService.fetchPendingStaffInvites(
        profile: profile,
        staffRole: 'electrician',
      );
    });
  }

  Future<void> _respondToInvite(
    QueryDocumentSnapshot doc,
    dynamic profile,
    bool accept,
  ) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      await GrihoStaffInviteService.respondToStaffInvite(
        doc: doc,
        profile: profile,
        staffRole: 'electrician',
        accept: accept,
      );
      AuthRouteGuard.clearAccessCache();
      ref.invalidate(currentUserProfileProvider);

      if (!mounted) {
        return;
      }
      _refreshInvites(profile);
      if (accept) {
        GrihoFeedback.showSuccess(context, 'Electrician assignment accepted!');
      } else {
        GrihoFeedback.showWarning(context, 'Invitation declined.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        'Error processing invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showLogMeterReadingDialog({
    required HomeJsonMap activeAssignment,
    required dynamic profile,
  }) async {
    final unitCtrl = TextEditingController();
    final prevCtrl = TextEditingController();
    final currCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '9.0');

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Record Unit Meter Reading'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrihoTextField(
                  controller: unitCtrl,
                  label: 'Unit Number / Label *',
                  hint: 'e.g. Unit 2A',
                  prefixIcon: Iconsax.home_2,
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: prevCtrl,
                  label: 'Previous Reading (kWh) *',
                  hint: 'e.g. 1250',
                  prefixIcon: Iconsax.flash_1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: currCtrl,
                  label: 'Current Reading (kWh) *',
                  hint: 'e.g. 1410',
                  prefixIcon: Iconsax.flash_circle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: rateCtrl,
                  label: 'Rate per Unit (৳/kWh) *',
                  prefixIcon: Iconsax.money_2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final prev = double.tryParse(prevCtrl.text.trim());
                final curr = double.tryParse(currCtrl.text.trim());
                final rate = double.tryParse(rateCtrl.text.trim());
                if (unitCtrl.text.trim().isEmpty ||
                    prev == null ||
                    curr == null ||
                    curr < prev ||
                    rate == null ||
                    rate <= 0) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Iconsax.flash_1, size: 18),
              label: const Text('Save Reading'),
            ),
          ],
        ),
      );

      if (saved != true || !mounted) {
        return;
      }

      final prev = double.parse(prevCtrl.text.trim());
      final curr = double.parse(currCtrl.text.trim());
      final rate = double.parse(rateCtrl.text.trim());
      final consumed = curr - prev;
      final totalBill = consumed * rate;

      await FirebaseFirestore.instance.collection('meterReadings').add({
        'ownerId': activeAssignment['ownerId'],
        'propertyId': activeAssignment['propertyId'],
        'propertyName': activeAssignment['propertyName'],
        'unitLabel': unitCtrl.text.trim(),
        'previousReading': prev,
        'currentReading': curr,
        'consumedUnits': consumed,
        'ratePerUnit': rate,
        'calculatedAmount': totalBill,
        'recordedByUid': profile.uid,
        'recordedByName': profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await AuditLoggerService.log(
        ownerId: (activeAssignment['ownerId'] ?? '').toString(),
        propertyId: (activeAssignment['propertyId'] ?? '').toString(),
        propertyName: (activeAssignment['propertyName'] ?? 'Building')
            .toString(),
        category: 'billing',
        actorRole: 'electrician',
        actionTitle: 'Electricity Meter Reading Logged',
        details:
            '${unitCtrl.text.trim()}:${consumed.toStringAsFixed(1)} kWh consumed (৳${totalBill.toStringAsFixed(0)}) logged by Electrician${profile.name}.',
      );

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        'Saved: ${consumed.toStringAsFixed(1)} kWh = ৳${totalBill.toStringAsFixed(0)}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Failed to save meter reading: $e');
    } finally {
      unitCtrl.dispose();
      prevCtrl.dispose();
      currCtrl.dispose();
      rateCtrl.dispose();
    }
  }

  void _openRepairsSheet(String propertyId, String actorName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: _ElectricalRepairsSheet(
            propertyId: propertyId,
            actorName: actorName,
          ),
        ),
      ),
    );
  }

  void _openMeterLogsSheet(
    String propertyId,
    HomeJsonMap activeAssignment,
    dynamic profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: _MeterLogsSheet(
            propertyId: propertyId,
            onAddReading: () => _showLogMeterReadingDialog(
              activeAssignment: activeAssignment,
              profile: profile,
            ),
          ),
        ),
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
      appBar: const GrihoHomeAppBar(consoleLabel: 'Electrician Console'),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading console...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: e.toString(),
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
                  title: 'Profile not found',
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
                builder: (context, inviteSnap) {
                  final pendingInvites =
                      inviteSnap.data ?? const <QueryDocumentSnapshot>[];
                  final accessDocs =
                      accessSnap.data?.docs ?? const <QueryDocumentSnapshot>[];

                  final activeAccessList = accessDocs
                      .map((d) => homeAsMap(d.data()))
                      .where((m) => (m['status'] ?? 'active') == 'active')
                      .toList();

                  if (activeAccessList.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _refreshInvites(profile),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 105),
                        children: [
                          GrihoHomeTopHeader(
                            name: profile.name,
                            publicId: profile.publicId,
                          ),
                          const SizedBox(height: 16),
                          for (final inv in pendingInvites)
                            Builder(
                              builder: (context) {
                                final d = homeAsMap(inv.data());
                                return GrihoPendingInviteBanner(
                                  title:
                                      'New Electrician Assignment: ${d['propertyName'] ?? 'Building'}',
                                  subtitle:
                                      'Invited by ${d['ownerName'] ?? 'Property Owner'}',
                                  acceptLabel: 'Accept Assignment',
                                  busy: _busy,
                                  onAccept: () =>
                                      _respondToInvite(inv, profile, true),
                                  onDecline: () =>
                                      _respondToInvite(inv, profile, false),
                                );
                              },
                            ),
                          GrihoStatusState(
                            icon: Iconsax.flash_1,
                            title: 'No Active Building Assignment',
                            subtitle:
                                'Provide your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) to the property owner to get authorized for meter readings and electrical repairs.',
                          ),
                        ],
                      ),
                    );
                  }

                  final currentAssignment = activeAccessList.firstWhere(
                    (a) => a['propertyId'] == _selectedPropertyId,
                    orElse: () => activeAccessList.first,
                  );
                  final activePropertyId =
                      (currentAssignment['propertyId'] ?? '').toString();
                  final activePropertyName =
                      (currentAssignment['propertyName'] ?? 'Assigned Building')
                          .toString();

                  _ensurePropertyStreams(activePropertyId);

                  return StreamBuilder<QuerySnapshot>(
                    stream: _metersStream,
                    builder: (context, metersSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _repairsStream,
                        builder: (context, repairsSnap) {
                          final meterDocs = metersSnap.data?.docs ?? [];
                          var totalMeterAmount = 0.0;
                          for (final d in meterDocs) {
                            final m = homeAsMap(d.data());
                            final amt = m['calculatedAmount'];
                            if (amt is num) {
                              totalMeterAmount += amt.toDouble();
                            }
                          }

                          final electricalDocs = (repairsSnap.data?.docs ?? [])
                              .where((doc) {
                                final d = homeAsMap(doc.data());
                                return (d['category'] ?? 'electrical') ==
                                    'electrical';
                              })
                              .toList();

                          final openRepairs = electricalDocs.where((doc) {
                            final d = homeAsMap(doc.data());
                            final s = (d['status'] ?? 'open').toString();
                            return s == 'open' || s == 'in_progress';
                          }).toList();

                          final billedText =
                              totalMeterAmount ==
                                  totalMeterAmount.roundToDouble()
                              ? totalMeterAmount.toStringAsFixed(0)
                              : totalMeterAmount.toStringAsFixed(2);

                          return RefreshIndicator(
                            onRefresh: () async => _refreshInvites(profile),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
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
                                for (final inv in pendingInvites)
                                  Builder(
                                    builder: (context) {
                                      final d = homeAsMap(inv.data());
                                      return GrihoPendingInviteBanner(
                                        title:
                                            'New Electrician Assignment: ${d['propertyName'] ?? 'Building'}',
                                        subtitle:
                                            'Invited by ${d['ownerName'] ?? 'Property Owner'}',
                                        acceptLabel: 'Accept Assignment',
                                        busy: _busy,
                                        onAccept: () => _respondToInvite(
                                          inv,
                                          profile,
                                          true,
                                        ),
                                        onDecline: () => _respondToInvite(
                                          inv,
                                          profile,
                                          false,
                                        ),
                                      );
                                    },
                                  ),
                                if (activeAccessList.length > 1) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: activePropertyId,
                                    decoration: const InputDecoration(
                                      labelText: 'Assigned Building',
                                      prefixIcon: Icon(
                                        Iconsax.buildings_2,
                                        color: GrihoColors.emerald,
                                      ),
                                      isDense: true,
                                    ),
                                    items: activeAccessList
                                        .map(
                                          (a) => DropdownMenuItem<String>(
                                            value: a['propertyId'].toString(),
                                            child: Text(
                                              (a['propertyName'] ?? 'Building')
                                                  .toString(),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedPropertyId = v);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                GrihoHeroCard(
                                  eyebrow: 'ASSIGNED BUILDING',
                                  eyebrowIcon: Iconsax.buildings_2,
                                  headline: activePropertyName,
                                  metrics: [
                                    GrihoHeroMetric(
                                      label: 'Open repairs',
                                      value: '${openRepairs.length}',
                                      highlight: openRepairs.isNotEmpty,
                                    ),
                                    GrihoHeroMetric(
                                      label: 'Meter logs',
                                      value: '${meterDocs.length}',
                                    ),
                                    GrihoHeroMetric(
                                      label: 'Logged value',
                                      value: '৳$billedText',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GrihoPrimaryButton(
                                        label: 'Log meter',
                                        icon: Iconsax.flash_1,
                                        onPressed: () =>
                                            _showLogMeterReadingDialog(
                                              activeAssignment:
                                                  currentAssignment,
                                              profile: profile,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GrihoSecondaryButton(
                                        label: 'Repairs',
                                        icon: Iconsax.setting_2,
                                        onPressed: () => _openRepairsSheet(
                                          activePropertyId,
                                          profile.name,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                const GrihoSectionHeader('Quick actions'),
                                const SizedBox(height: 10),
                                GrihoQuickActionGrid(
                                  items: [
                                    GrihoQuickActionItem(
                                      icon: Iconsax.flash_1,
                                      title: 'Log meter',
                                      subtitle: 'Record kWh usage',
                                      color: GrihoColors.warning,
                                      onTap: () => _showLogMeterReadingDialog(
                                        activeAssignment: currentAssignment,
                                        profile: profile,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.receipt_item,
                                      title: 'Meter logs',
                                      subtitle: '${meterDocs.length} recorded',
                                      color: GrihoColors.emerald,
                                      onTap: () => _openMeterLogsSheet(
                                        activePropertyId,
                                        currentAssignment,
                                        profile,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.flash_circle,
                                      title: 'Electrical repairs',
                                      subtitle: '${openRepairs.length} open',
                                      color: Colors.deepOrange,
                                      onTap: () => _openRepairsSheet(
                                        activePropertyId,
                                        profile.name,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.notification_bing,
                                      title: 'Notice board',
                                      subtitle: 'View building alerts',
                                      color: Colors.indigo,
                                      onTap: () =>
                                          context.go(RouteNames.notices),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                GrihoSectionHeader(
                                  'Electrical repair tickets',
                                  trailing: electricalDocs.isNotEmpty
                                      ? TextButton(
                                          onPressed: () => _openRepairsSheet(
                                            activePropertyId,
                                            profile.name,
                                          ),
                                          child: const Text('View all'),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                _ElectricalRepairsList(
                                  docs: electricalDocs.take(4).toList(),
                                  actorName: profile.name,
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
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
      ),
    );
  }
}

class _ElectricalRepairsList extends StatelessWidget {
  const _ElectricalRepairsList({required this.docs, required this.actorName});

  final HomeDocList docs;
  final String actorName;

  Future<void> _updateStatus(
    BuildContext context,
    DocumentSnapshot doc,
    String nextStatus,
  ) async {
    try {
      await doc.reference.update({
        'status': nextStatus,
        'handledByName': actorName,
        'handledByRole': 'electrician',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        nextStatus == 'resolved'
            ? 'Electrical repair marked completed.'
            : 'Repair marked in progress.',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Unable to update ticket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (docs.isEmpty) {
      return const GrihoStatusState(
        icon: Iconsax.tick_circle,
        title: 'All clear',
        subtitle: 'No electrical repair tickets pending.',
      );
    }

    return Column(
      children: [
        for (final doc in docs)
          Builder(
            builder: (context) {
              final d = homeAsMap(doc.data());
              final title = (d['title'] ?? 'Electrical Issue').toString();
              final desc = (d['description'] ?? '').toString();
              final unitName = (d['unitName'] ?? 'Building').toString();
              final status = (d['status'] ?? 'open').toString();
              final isResolved = status == 'resolved';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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
                      unitName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc, style: theme.textTheme.bodySmall),
                    ],
                    if (!isResolved) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (status == 'open') ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(context, doc, 'in_progress'),
                                child: const Text('Start Repair'),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () =>
                                  _updateStatus(context, doc, 'resolved'),
                              child: const Text('Mark Completed'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ElectricalRepairsSheet extends StatelessWidget {
  final String propertyId;
  final String actorName;

  const _ElectricalRepairsSheet({
    required this.propertyId,
    required this.actorName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('maintenanceRequests')
          .where('propertyId', isEqualTo: propertyId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const GrihoLoadingView(message: 'Loading repair tickets...');
        }
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = homeAsMap(doc.data());
          return (d['category'] ?? 'electrical') == 'electrical';
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'All Electrical Repair Tickets',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _ElectricalRepairsList(docs: docs, actorName: actorName),
          ],
        );
      },
    );
  }
}

class _MeterLogsSheet extends StatelessWidget {
  final String propertyId;
  final VoidCallback onAddReading;

  const _MeterLogsSheet({required this.propertyId, required this.onAddReading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meterReadings')
          .where('propertyId', isEqualTo: propertyId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const GrihoLoadingView(message: 'Loading meter logs...');
        }
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Electricity Meter Readings',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAddReading();
                  },
                  icon: const Icon(Iconsax.add, size: 18),
                  label: const Text('Log kWh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: GrihoStatusState(
                  icon: Iconsax.flash_1,
                  title: 'No meter readings yet',
                  subtitle: 'Record unit kWh readings to calculate bills.',
                ),
              ),
            for (final doc in docs)
              Builder(
                builder: (context) {
                  final d = homeAsMap(doc.data());
                  final unitLabel = (d['unitLabel'] ?? 'Unit').toString();
                  final prev = (d['previousReading'] ?? 0).toString();
                  final curr = (d['currentReading'] ?? 0).toString();
                  final consumed = (d['consumedUnits'] ?? 0).toString();
                  final amount = (d['calculatedAmount'] ?? 0).toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: GrihoColors.warning.withValues(
                            alpha: 0.16,
                          ),
                          child: const Icon(
                            Iconsax.flash_1,
                            size: 18,
                            color: GrihoColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unitLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Reading: $prev → $curr kWh ($consumed kWh used)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '৳$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
