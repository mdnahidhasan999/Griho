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
import '../../../../core/services/audit_logger_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ElectricianHomeScreen extends ConsumerStatefulWidget {
  const ElectricianHomeScreen({super.key});

  @override
  ConsumerState<ElectricianHomeScreen> createState() =>
      _ElectricianHomeScreenState();
}

class _ElectricianHomeScreenState extends ConsumerState<ElectricianHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String? _selectedPropertyId;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> _fetchElectricianInvites(
    dynamic profile,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('staffInvitations');
    final Map<String, QueryDocumentSnapshot> results = {};

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
          final data = doc.data() as Map<String, dynamic>? ?? {};
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
      final firestore = FirebaseFirestore.instance;
      final data = doc.data() as Map<String, dynamic>? ?? {};
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
      setState(() {});
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
          content: Text('Error processing invitation: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showLogMeterReadingDialog({
    required Map<String, dynamic> activeAssignment,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.electrical_services_rounded,
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
                  ),
                ),
                Text(
                  'Electrician Console',
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.electric_meter_outlined), text: 'Meter Logs'),
            Tab(icon: Icon(Icons.bolt_rounded), text: 'Electrical Repairs'),
          ],
        ),
      ),
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
              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchElectricianInvites(profile),
                builder: (context, inviteSnap) {
                  final invites = inviteSnap.data ?? [];
                  final pendingInvites = invites.where((d) {
                    final map = d.data() as Map<String, dynamic>? ?? {};
                    return (map['status'] ?? 'pending') == 'pending';
                  }).toList();

                  final accessDocs = accessSnap.data?.docs ?? [];
                  final activeAccessList = accessDocs
                      .map((d) => d.data() as Map<String, dynamic>? ?? {})
                      .where((m) => (m['status'] ?? 'active') == 'active')
                      .toList();

                  if (activeAccessList.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _ElectricianHeader(
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.electrical_services_outlined,
                                size: 48,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Active Building Assignment',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Provide your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) to the property owner to get authorized for meter readings and electrical repairs.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  final currentAssignment = activeAccessList.firstWhere(
                    (a) => a['propertyId'] == _selectedPropertyId,
                    orElse: () => activeAccessList.first,
                  );
                  final activePropertyId =
                      (currentAssignment['propertyId'] ?? '').toString();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          children: [
                            _ElectricianHeader(
                              name: profile.name,
                              publicId: profile.publicId,
                            ),
                            if (pendingInvites.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              for (final inv in pendingInvites)
                                _ElectricianInviteBanner(
                                  doc: inv,
                                  busy: _busy,
                                  onAccept: () =>
                                      _respondToInvite(inv, profile, true),
                                  onDecline: () =>
                                      _respondToInvite(inv, profile, false),
                                ),
                            ],
                            if (activeAccessList.length > 1) ...[
                              const SizedBox(height: 10),
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
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _MeterReadingsTab(
                              propertyId: activePropertyId,
                              onAddReading: () => _showLogMeterReadingDialog(
                                activeAssignment: currentAssignment,
                                profile: profile,
                              ),
                            ),
                            _ElectricalRepairsTab(
                              propertyId: activePropertyId,
                              actorName: profile.name,
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
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.electricianHome),
        onMoreTap: () => context.push(RouteNames.more),
      ),
    );
  }
}

class _ElectricianHeader extends StatelessWidget {
  final String name;
  final String publicId;

  const _ElectricianHeader({required this.name, required this.publicId});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (publicId.isNotEmpty)
          ActionChip(
            avatar: const Icon(Icons.badge_outlined, size: 16),
            label: Text(
              publicId,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: publicId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Griho ID copied.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final propName = (data['propertyName'] ?? 'Building').toString();
    final ownerName = (data['ownerName'] ?? 'Property Owner').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

class _MeterReadingsTab extends StatelessWidget {
  final String propertyId;
  final VoidCallback onAddReading;

  const _MeterReadingsTab({
    required this.propertyId,
    required this.onAddReading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddReading,
        icon: const Icon(Icons.electric_meter_rounded),
        label: const Text('Log Meter Reading'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meterReadings')
            .where('propertyId', isEqualTo: propertyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No unit electricity meter readings logged yet. Tap "Log Meter Reading" below to record monthly kWh consumption.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>? ?? {};
              final unitLabel = (d['unitLabel'] ?? 'Unit').toString();
              final prev = (d['previousReading'] ?? 0).toString();
              final curr = (d['currentReading'] ?? 0).toString();
              final consumed = (d['consumedUnits'] ?? 0).toString();
              final amount = (d['calculatedAmount'] ?? 0).toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
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
          );
        },
      ),
    );
  }
}

class _ElectricalRepairsTab extends StatelessWidget {
  final String propertyId;
  final String actorName;

  const _ElectricalRepairsTab({
    required this.propertyId,
    required this.actorName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('maintenanceRequests')
          .where('propertyId', isEqualTo: propertyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>? ?? {};
          return (d['category'] ?? 'electrical') == 'electrical';
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No electrical repair tickets pending for this building.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>? ?? {};
            final title = (d['title'] ?? 'Electrical Issue').toString();
            final desc = (d['description'] ?? '').toString();
            final unitName = (d['unitName'] ?? 'Building').toString();
            final status = (d['status'] ?? 'open').toString();
            final isResolved = status == 'resolved';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
                    unitName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(desc, style: theme.textTheme.bodySmall),
                  ],
                  if (!isResolved) ...[
                    const SizedBox(height: 12),
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
        );
      },
    );
  }
}
