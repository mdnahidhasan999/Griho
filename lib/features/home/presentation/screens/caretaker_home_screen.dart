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

class CaretakerHomeScreen extends ConsumerStatefulWidget {
  const CaretakerHomeScreen({super.key});

  @override
  ConsumerState<CaretakerHomeScreen> createState() =>
      _CaretakerHomeScreenState();
}

class _CaretakerHomeScreenState extends ConsumerState<CaretakerHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String? _selectedPropertyId;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> _fetchCaretakerInvites(
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
          if ((data['staffRole'] ?? 'caretaker') == 'caretaker') {
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
            .doc('${profile.uid}_${propertyId}_caretaker');
        batch.set(accessRef, {
          'userId': profile.uid,
          'staffName': profile.name,
          'staffGrihoId': profile.publicId,
          'staffPhone': profile.phoneNumber,
          'staffRole': 'caretaker',
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
        if (!currentRoles.contains('caretaker')) {
          batch.update(firestore.collection('users').doc(profile.uid), {
            'availableRoles': FieldValue.arrayUnion(['caretaker']),
            'defaultDashboard': 'caretaker',
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
            accept ? 'Caretaker assignment accepted!' : 'Invitation declined.',
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

  Future<void> _updateTicketStatus({
    required DocumentSnapshot doc,
    required String nextStatus,
    required String actorName,
  }) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String note = '';

    if (nextStatus == 'resolved') {
      final confirmedNote = await showDialog<String>(
        context: context,
        builder: (ctx) {
          var draft = '';
          return AlertDialog(
            title: const Text('Mark Issue Resolved'),
            content: TextField(
              autofocus: true,
              maxLines: 2,
              onChanged: (v) => draft = v,
              decoration: const InputDecoration(
                labelText: 'Resolution Note (Optional)',
                hintText: 'e.g. Pipe leak repaired and tested',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, draft.trim()),
                child: const Text('Complete'),
              ),
            ],
          );
        },
      );
      if (confirmedNote == null) return;
      note = confirmedNote;
    }

    try {
      await doc.reference.update({
        'status': nextStatus,
        'handledByName': actorName,
        'handledByRole': 'caretaker',
        if (note.isNotEmpty) 'resolutionNote': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AuditLoggerService.log(
        ownerId: (data['ownerId'] ?? '').toString(),
        propertyId: (data['propertyId'] ?? '').toString(),
        propertyName: (data['propertyName'] ?? 'Building').toString(),
        category: 'maintenance',
        actorRole: 'caretaker',
        actionTitle: 'Maintenance Ticket ${nextStatus.toUpperCase()}',
        details:
            'Ticket "${data['title'] ?? 'Issue'}" (${data['unitName'] ?? 'Building'}) marked $nextStatus by Caretaker$actorName.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update ticket: $e')));
    }
  }

  Future<void> _showAddVisitorDialog({
    required Map<String, dynamic> activeAssignment,
    required dynamic profile,
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log New Visitor / Delivery'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Visitor Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Unit / Floor *',
                  hintText: 'e.g. Unit 3B',
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose / Delivery Details',
                  hintText: 'e.g. Guest / Parcel Delivery',
                  prefixIcon: Icon(Icons.assignment_outlined),
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
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty ||
                  unitCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Check In'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('visitorLogs').add({
        'ownerId': activeAssignment['ownerId'],
        'propertyId': activeAssignment['propertyId'],
        'propertyName': activeAssignment['propertyName'],
        'visitorName': nameCtrl.text.trim(),
        'visitorPhone': phoneCtrl.text.trim(),
        'targetUnit': unitCtrl.text.trim(),
        'purpose': purposeCtrl.text.trim().isEmpty
            ? 'Guest Visit'
            : purposeCtrl.text.trim(),
        'status': 'checked_in',
        'loggedByUid': profile.uid,
        'loggedByName': profile.name,
        'checkInAt': FieldValue.serverTimestamp(),
        'checkOutAt': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visitor checked in successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log visitor: $e')));
    }
  }

  Future<void> _showPostNoticeDialog({
    required Map<String, dynamic> activeAssignment,
    required dynamic profile,
  }) async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String priority = 'normal';

    final posted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Post Building Notice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notice Title *',
                    hintText: 'e.g. Water Tank Cleaning Tomorrow',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details / Schedule *',
                    hintText: 'Water supply will be paused from 10 AM to 1 PM.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Urgency Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                      value: 'important',
                      child: Text('Important'),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('Urgent Alert'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => priority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    messageCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Publish Notice'),
            ),
          ],
        ),
      ),
    );

    if (posted != true || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('buildingNotices').add({
        'ownerId': activeAssignment['ownerId'],
        'propertyId': activeAssignment['propertyId'],
        'propertyName': activeAssignment['propertyName'],
        'title': titleCtrl.text.trim(),
        'message': messageCtrl.text.trim(),
        'priority': priority,
        'postedByUid': profile.uid,
        'postedByName': profile.name,
        'postedByRole': 'caretaker',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building notice published.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to publish notice: $e')));
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.handyman_rounded,
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
                  'Caretaker Console',
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
            Tab(icon: Icon(Icons.build_circle_outlined), text: 'Maintenance'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Visitor Log'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Notices'),
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
                .where('staffRole', isEqualTo: 'caretaker')
                .snapshots(),
            builder: (context, accessSnap) {
              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchCaretakerInvites(profile),
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
                        _CaretakerHeader(
                          name: profile.name,
                          publicId: profile.publicId,
                        ),
                        const SizedBox(height: 16),
                        for (final inv in pendingInvites)
                          _PendingStaffInviteCard(
                            doc: inv,
                            roleTitle: 'Building Caretaker',
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
                                Icons.handyman_outlined,
                                size: 48,
                                color: theme.colorScheme.primary,
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
                                'Share your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) with the property owner to receive a Caretaker assignment.',
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
                            _CaretakerHeader(
                              name: profile.name,
                              publicId: profile.publicId,
                            ),
                            if (pendingInvites.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              for (final inv in pendingInvites)
                                _PendingStaffInviteCard(
                                  doc: inv,
                                  roleTitle: 'Building Caretaker',
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
                            _CaretakerMaintenanceTab(
                              propertyId: activePropertyId,
                              onUpdateStatus: (doc, status) =>
                                  _updateTicketStatus(
                                    doc: doc,
                                    nextStatus: status,
                                    actorName: profile.name,
                                  ),
                            ),
                            _CaretakerVisitorTab(
                              propertyId: activePropertyId,
                              onAddVisitor: () => _showAddVisitorDialog(
                                activeAssignment: currentAssignment,
                                profile: profile,
                              ),
                            ),
                            _CaretakerNoticesTab(
                              propertyId: activePropertyId,
                              onPostNotice: () => _showPostNoticeDialog(
                                activeAssignment: currentAssignment,
                                profile: profile,
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
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.caretakerHome),
        onMoreTap: () => context.push(RouteNames.more),
      ),
    );
  }
}

class _CaretakerHeader extends StatelessWidget {
  final String name;
  final String publicId;

  const _CaretakerHeader({required this.name, required this.publicId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'On-Duty Supervisor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (publicId.isNotEmpty)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: publicId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Griho ID copied.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                publicId,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingStaffInviteCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String roleTitle;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingStaffInviteCard({
    required this.doc,
    required this.roleTitle,
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
            'New $roleTitle Assignment:$propName',
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

class _CaretakerMaintenanceTab extends StatelessWidget {
  final String propertyId;
  final void Function(DocumentSnapshot doc, String status) onUpdateStatus;

  const _CaretakerMaintenanceTab({
    required this.propertyId,
    required this.onUpdateStatus,
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

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>? ?? {};
          return (d['category'] ?? 'general') != 'electrical';
        }).toList();
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No maintenance or plumbing requests reported for this building yet.',
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
            final title = (d['title'] ?? 'Maintenance Issue').toString();
            final desc = (d['description'] ?? '').toString();
            final unitName = (d['unitName'] ?? 'Common Area').toString();
            final category = (d['category'] ?? 'general').toString();
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
                    '$unitName • Category: ${category.toUpperCase()}',
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
                              onPressed: () =>
                                  onUpdateStatus(doc, 'in_progress'),
                              child: const Text('Start Work'),
                            ),
                          ),
                        if (status == 'open') const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => onUpdateStatus(doc, 'resolved'),
                            child: const Text('Mark Resolved'),
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

class _CaretakerVisitorTab extends StatelessWidget {
  final String propertyId;
  final VoidCallback onAddVisitor;

  const _CaretakerVisitorTab({
    required this.propertyId,
    required this.onAddVisitor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddVisitor,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Log Visitor'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitorLogs')
            .where('propertyId', isEqualTo: propertyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No visitor entries logged yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data() as Map<String, dynamic>? ?? {};
              final name = (d['visitorName'] ?? 'Visitor').toString();
              final unit = (d['targetUnit'] ?? '').toString();
              final purpose = (d['purpose'] ?? '').toString();
              final status = (d['status'] ?? 'checked_in').toString();
              final isInside = status == 'checked_in';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isInside
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      child: Icon(
                        isInside ? Icons.login_rounded : Icons.logout_rounded,
                        color: isInside ? Colors.green.shade800 : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name → $unit',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(purpose, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (isInside)
                      OutlinedButton(
                        onPressed: () {
                          doc.reference.update({
                            'status': 'checked_out',
                            'checkOutAt': FieldValue.serverTimestamp(),
                          });
                        },
                        child: const Text('Check Out'),
                      )
                    else
                      const Text(
                        'LEFT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
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

class _CaretakerNoticesTab extends StatelessWidget {
  final String propertyId;
  final VoidCallback onPostNotice;

  const _CaretakerNoticesTab({
    required this.propertyId,
    required this.onPostNotice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onPostNotice,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Post Notice'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buildingNotices')
            .where('propertyId', isEqualTo: propertyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No building notices posted yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>? ?? {};
              final title = (d['title'] ?? 'Notice').toString();
              final msg = (d['message'] ?? '').toString();
              final priority = (d['priority'] ?? 'normal').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: priority == 'urgent'
                        ? Colors.red.shade400
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(msg, style: theme.textTheme.bodyMedium),
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
