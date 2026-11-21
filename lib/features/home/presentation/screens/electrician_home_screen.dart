// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_route_guard.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/griho_home_chrome.dart';

typedef JsonMap = Map<String, dynamic>;
typedef _DocList = List<QueryDocumentSnapshot>;

class ElectricianHomeScreen extends ConsumerStatefulWidget {
  const ElectricianHomeScreen({super.key});

  @override
  ConsumerState<ElectricianHomeScreen> createState() =>
      _ElectricianHomeScreenState();
}

class _ElectricianHomeScreenState extends ConsumerState<ElectricianHomeScreen> {
  bool _busy = false;
  String? _selectedPropertyId;

  Future<_DocList>? _invitesFuture;
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

  Future<_DocList> _getOrFetchInvites(dynamic profile) {
    final uid = profile.uid.toString().trim();
    if (_invitesFuture == null || _cachedForUid != uid) {
      _cachedForUid = uid;
      _invitesFuture = _fetchElectricianInvites(profile);
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = _fetchElectricianInvites(profile);
    });
  }

  Future<_DocList> _fetchElectricianInvites(dynamic profile) async {
    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('staffInvitations');
    final results = <String, QueryDocumentSnapshot>{};

    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final publicId = profile.publicId.toString().trim();
    final email = (profile.email ?? '').toString().trim();

    final queries = <Future<QuerySnapshot>>[
      if (uid.isNotEmpty) col.where('staffUserId', isEqualTo: uid).get(),
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
          final data = doc.data() as JsonMap? ?? <String, dynamic>{};
          if ((data['staffRole'] ?? '') == 'electrician') {
            results[doc.id] = doc;
          }
        }
      } catch (_) {}
    }

    return results.values.toList();
  }

  Future<void> _respondToInvite(
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
      final data = doc.data() as JsonMap? ?? <String, dynamic>{};
      final propertyId = (data['propertyId'] ?? '').toString().trim();
      final ownerId = (data['ownerId'] ?? '').toString().trim();

      final batch = firestore.batch();

      batch.update(doc.reference, {
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
        final accessRef = firestore
            .collection('staffAccess')
            .doc('${profile.uid}_${propertyId}_electrician');
        batch.set(accessRef, {
          'userId': profile.uid,
          'staffName': profile.name,
          'staffGrihoId': profile.publicId,
          'staffPhone': profile.phoneNumber,
          'staffRole': 'electrician',
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
        if (!currentRoles.contains('electrician')) {
          batch.update(firestore.collection('users').doc(profile.uid), {
            'availableRoles': FieldValue.arrayUnion(['electrician']),
            'defaultDashboard': 'electrician',
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
                ? 'Electrician assignment accepted!'
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
            'Error processing invitation: ${e.toString().replaceFirst('Bad state: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showLogMeterReadingDialog({
    required JsonMap activeAssignment,
    required dynamic profile,
  }) async {
    final unitCtrl = TextEditingController();
    final prevCtrl = TextEditingController();
    final currCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '9.0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Unit Meter Reading'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit Number / Label *',
                  hintText: 'e.g. Unit 2A',
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prevCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Previous Reading (kWh) *',
                  hintText: 'e.g. 1250',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: currCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Current Reading (kWh) *',
                  hintText: 'e.g. 1410',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Rate per Unit (৳/kWh) *',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
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
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Save Reading'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final prev = double.parse(prevCtrl.text.trim());
    final curr = double.parse(currCtrl.text.trim());
    final rate = double.parse(rateCtrl.text.trim());
    final consumed = curr - prev;
    final totalBill = consumed * rate;

    try {
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
            '${unitCtrl.text.trim()}: ${consumed.toStringAsFixed(1)} kWh consumed (৳${totalBill.toStringAsFixed(0)}) logged by Electrician ${profile.name}.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved: ${consumed.toStringAsFixed(1)} kWh = ৳${totalBill.toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save meter reading: $e')),
      );
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
    JsonMap activeAssignment,
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
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      extendBody: true,

      backgroundColor: theme.colorScheme.surface,
      appBar: const GrihoHomeAppBar(consoleLabel: 'Electrician Console'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('staffAccess')
                .where('userId', isEqualTo: profile.uid)
                .where('staffRole', isEqualTo: 'electrician')
                .snapshots(),
            builder: (context, accessSnap) {
              return FutureBuilder<_DocList>(
                future: _getOrFetchInvites(profile),
                builder: (context, inviteSnap) {
                  final invites = inviteSnap.data ?? [];
                  final pendingInvites = invites.where((d) {
                    final map = d.data() as JsonMap? ?? <String, dynamic>{};
                    return (map['status'] ?? 'pending') == 'pending';
                  }).toList();

                  final accessDocs = accessSnap.data?.docs ?? [];
                  final activeAccessList = accessDocs
                      .map((d) => d.data() as JsonMap? ?? <String, dynamic>{})
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
                            _ElectricianInviteBanner(
                              doc: inv,
                              busy: _busy,
                              onAccept: () =>
                                  _respondToInvite(inv, profile, true),
                              onDecline: () =>
                                  _respondToInvite(inv, profile, false),
                            ),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.electrical_services_outlined,
                                    size: 40,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Active Building Assignment',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Provide your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) to the property owner to get authorized for meter readings and electrical repairs.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
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

                  return StreamBuilder<QuerySnapshot>(
                    stream: firestore
                        .collection('meterReadings')
                        .where('propertyId', isEqualTo: activePropertyId)
                        .snapshots(),
                    builder: (context, metersSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('maintenanceRequests')
                            .where('propertyId', isEqualTo: activePropertyId)
                            .snapshots(),
                        builder: (context, repairsSnap) {
                          final meterDocs = metersSnap.data?.docs ?? [];
                          var totalMeterAmount = 0.0;
                          for (final d in meterDocs) {
                            final m =
                                d.data() as JsonMap? ?? <String, dynamic>{};
                            final amt = m['calculatedAmount'];
                            if (amt is num) {
                              totalMeterAmount += amt.toDouble();
                            }
                          }

                          final electricalDocs = (repairsSnap.data?.docs ?? [])
                              .where((doc) {
                                final d =
                                    doc.data() as JsonMap? ??
                                    <String, dynamic>{};
                                return (d['category'] ?? 'electrical') ==
                                    'electrical';
                              })
                              .toList();

                          final openRepairs = electricalDocs.where((doc) {
                            final d =
                                doc.data() as JsonMap? ?? <String, dynamic>{};
                            final s = (d['status'] ?? 'open').toString();
                            return s == 'open' || s == 'in_progress';
                          }).toList();

                          return RefreshIndicator(
                            onRefresh: () async => _refreshInvites(profile),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                              children: [
                                GrihoHomeTopHeader(
                                  name: profile.name,
                                  publicId: profile.publicId,
                                ),
                                const SizedBox(height: 16),

                                if (pendingInvites.isNotEmpty)
                                  for (final inv in pendingInvites)
                                    _ElectricianInviteBanner(
                                      doc: inv,
                                      busy: _busy,
                                      onAccept: () =>
                                          _respondToInvite(inv, profile, true),
                                      onDecline: () =>
                                          _respondToInvite(inv, profile, false),
                                    ),

                                if (activeAccessList.length > 1) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: activePropertyId,
                                    decoration: const InputDecoration(
                                      labelText: 'Assigned Building',
                                      prefixIcon: Icon(Icons.apartment_rounded),
                                      border: OutlineInputBorder(),
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

                                // Unified Dark Hero Console Card
                                _ElectricianSummaryCard(
                                  propertyName: activePropertyName,
                                  openRepairs: openRepairs.length,
                                  meterCount: meterDocs.length,
                                  totalBilled: totalMeterAmount,
                                ),
                                const SizedBox(height: 14),

                                // Primary Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showLogMeterReadingDialog(
                                              activeAssignment:
                                                  currentAssignment,
                                              profile: profile,
                                            ),
                                        icon: const Icon(
                                          Icons.electric_meter_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('Log meter'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        onPressed: () => _openRepairsSheet(
                                          activePropertyId,
                                          profile.name,
                                        ),
                                        icon: const Icon(
                                          Icons.bolt_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('Repairs'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),

                                Text(
                                  'Quick actions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Unified 2-Column Quick Actions Grid
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 2.3,
                                  children: [
                                    _QuickTile(
                                      icon: Icons.electric_meter_outlined,
                                      title: 'Log meter',
                                      subtitle: 'Record kWh usage',
                                      color: Colors.amber.shade800,
                                      onTap: () => _showLogMeterReadingDialog(
                                        activeAssignment: currentAssignment,
                                        profile: profile,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.receipt_long_rounded,
                                      title: 'Meter logs',
                                      subtitle: '${meterDocs.length} recorded',
                                      color: Colors.teal,
                                      onTap: () => _openMeterLogsSheet(
                                        activePropertyId,
                                        currentAssignment,
                                        profile,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.bolt_rounded,
                                      title: 'Electrical repairs',
                                      subtitle: '${openRepairs.length} open',
                                      color: Colors.deepOrange,
                                      onTap: () => _openRepairsSheet(
                                        activePropertyId,
                                        profile.name,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.campaign_outlined,
                                      title: 'Notice board',
                                      subtitle: 'View building alerts',
                                      color: Colors.indigo,
                                      onTap: () =>
                                          context.go(RouteNames.notices),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Electrical repair tickets',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    if (electricalDocs.isNotEmpty)
                                      TextButton(
                                        onPressed: () => _openRepairsSheet(
                                          activePropertyId,
                                          profile.name,
                                        ),
                                        child: const Text('View all'),
                                      ),
                                  ],
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

class _ElectricianSummaryCard extends StatelessWidget {
  const _ElectricianSummaryCard({
    required this.propertyName,
    required this.openRepairs,
    required this.meterCount,
    required this.totalBilled,
  });

  final String propertyName;
  final int openRepairs;
  final int meterCount;
  final double totalBilled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final billedText = totalBilled == totalBilled.roundToDouble()
        ? totalBilled.toStringAsFixed(0)
        : totalBilled.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E222D), Color(0xFF141720)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ASSIGNED BUILDING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            propertyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DarkMetric(
                label: 'Open repairs',
                value: '$openRepairs',
                highlight: openRepairs > 0,
              ),
              _DarkMetric(label: 'Meter logs', value: '$meterCount'),
              _DarkMetric(label: 'Logged value', value: '৳$billedText'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.amberAccent : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElectricianInviteBanner extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ElectricianInviteBanner({
    required this.doc,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as JsonMap? ?? <String, dynamic>{};
    final propName = (data['propertyName'] ?? 'Building').toString();
    final ownerName = (data['ownerName'] ?? 'Property Owner').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade800, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Electrician Assignment: $propName',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text('Invited by $ownerName'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: const Text('Accept Assignment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ElectricalRepairsList extends StatelessWidget {
  const _ElectricalRepairsList({required this.docs, required this.actorName});

  final _DocList docs;
  final String actorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            'No electrical repair tickets pending.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final doc in docs)
          Builder(
            builder: (context) {
              final d = doc.data() as JsonMap? ?? <String, dynamic>{};
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
                          if (status == 'open')
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  doc.reference.update({
                                    'status': 'in_progress',
                                    'handledByName': actorName,
                                    'handledByRole': 'electrician',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                },
                                child: const Text('Start Repair'),
                              ),
                            ),
                          if (status == 'open') const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () {
                                doc.reference.update({
                                  'status': 'resolved',
                                  'handledByName': actorName,
                                  'handledByRole': 'electrician',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              },
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
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = doc.data() as JsonMap? ?? <String, dynamic>{};
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
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log kWh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No unit electricity meter readings logged yet.'),
                ),
              ),
            for (final doc in docs)
              Builder(
                builder: (context) {
                  final d = doc.data() as JsonMap? ?? <String, dynamic>{};
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
                          backgroundColor: Colors.amber.withValues(alpha: 0.16),
                          child: Icon(
                            Icons.bolt_rounded,
                            color: Colors.amber.shade900,
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
