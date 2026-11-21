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

class CaretakerHomeScreen extends ConsumerStatefulWidget {
  const CaretakerHomeScreen({super.key});

  @override
  ConsumerState<CaretakerHomeScreen> createState() =>
      _CaretakerHomeScreenState();
}

class _CaretakerHomeScreenState extends ConsumerState<CaretakerHomeScreen> {
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
      _invitesFuture = _fetchCaretakerInvites(profile);
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = _fetchCaretakerInvites(profile);
    });
  }

  Future<_DocList> _fetchCaretakerInvites(dynamic profile) async {
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
      _refreshInvites(profile);
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

  Future<void> _updateTicketStatus({
    required DocumentSnapshot doc,
    required String nextStatus,
    required String actorName,
  }) async {
    final data = doc.data() as JsonMap? ?? <String, dynamic>{};
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
            'Ticket "${data['title'] ?? 'Issue'}" (${data['unitName'] ?? 'Building'}) marked $nextStatus by Caretaker $actorName.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update ticket: $e')));
    }
  }

  Future<void> _showAddVisitorDialog({
    required JsonMap activeAssignment,
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
    required JsonMap activeAssignment,
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

  void _openMaintenanceSheet(String propertyId, String actorName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: _CaretakerMaintenanceList(
            propertyId: propertyId,
            onUpdateStatus: (doc, status) => _updateTicketStatus(
              doc: doc,
              nextStatus: status,
              actorName: actorName,
            ),
          ),
        ),
      ),
    );
  }

  void _openVisitorSheet(
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
          child: _CaretakerVisitorSheet(
            propertyId: propertyId,
            onAddVisitor: () => _showAddVisitorDialog(
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
      appBar: const GrihoHomeAppBar(consoleLabel: 'Caretaker Console'),
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
                            _PendingStaffInviteCard(
                              doc: inv,
                              roleTitle: 'Building Caretaker',
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
                                    Icons.handyman_outlined,
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
                                  'Share your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) with the property owner to receive a Caretaker assignment.',
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
                        .collection('maintenanceRequests')
                        .where('propertyId', isEqualTo: activePropertyId)
                        .snapshots(),
                    builder: (context, issuesSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('visitorLogs')
                            .where('propertyId', isEqualTo: activePropertyId)
                            .snapshots(),
                        builder: (context, visitorsSnap) {
                          final generalDocs = (issuesSnap.data?.docs ?? [])
                              .where((doc) {
                                final d =
                                    doc.data() as JsonMap? ??
                                    <String, dynamic>{};
                                return (d['category'] ?? 'general') !=
                                    'electrical';
                              })
                              .toList();

                          final openTasks = generalDocs.where((doc) {
                            final d =
                                doc.data() as JsonMap? ?? <String, dynamic>{};
                            final s = (d['status'] ?? 'open').toString();
                            return s == 'open' || s == 'in_progress';
                          }).toList();

                          final visitorDocs = visitorsSnap.data?.docs ?? [];
                          final insideVisitorsCount = visitorDocs.where((doc) {
                            final d =
                                doc.data() as JsonMap? ?? <String, dynamic>{};
                            return (d['status'] ?? 'checked_in') ==
                                'checked_in';
                          }).length;

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
                                    _PendingStaffInviteCard(
                                      doc: inv,
                                      roleTitle: 'Building Caretaker',
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
                                _CaretakerSummaryCard(
                                  propertyName: activePropertyName,
                                  openTasks: openTasks.length,
                                  visitorsInside: insideVisitorsCount,
                                  totalLogs: visitorDocs.length,
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
                                        onPressed: () => _showAddVisitorDialog(
                                          activeAssignment: currentAssignment,
                                          profile: profile,
                                        ),
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('Log visitor'),
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
                                        onPressed: () => _showPostNoticeDialog(
                                          activeAssignment: currentAssignment,
                                          profile: profile,
                                        ),
                                        icon: const Icon(
                                          Icons.campaign_outlined,
                                          size: 20,
                                        ),
                                        label: const Text('Post notice'),
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
                                      icon: Icons.build_circle_outlined,
                                      title: 'Maintenance',
                                      subtitle: '${openTasks.length} open',
                                      color: Colors.deepOrange,
                                      onTap: () => _openMaintenanceSheet(
                                        activePropertyId,
                                        profile.name,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.badge_outlined,
                                      title: 'Visitor log',
                                      subtitle: '$insideVisitorsCount inside',
                                      color: Colors.teal,
                                      onTap: () => _openVisitorSheet(
                                        activePropertyId,
                                        currentAssignment,
                                        profile,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.campaign_outlined,
                                      title: 'Post notice',
                                      subtitle: 'Alert residents',
                                      color: Colors.amber.shade800,
                                      onTap: () => _showPostNoticeDialog(
                                        activeAssignment: currentAssignment,
                                        profile: profile,
                                      ),
                                    ),
                                    _QuickTile(
                                      icon: Icons.notifications_active_outlined,
                                      title: 'Notice board',
                                      subtitle: 'View all notices',
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
                                      'Maintenance tasks',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    if (generalDocs.isNotEmpty)
                                      TextButton(
                                        onPressed: () => _openMaintenanceSheet(
                                          activePropertyId,
                                          profile.name,
                                        ),
                                        child: const Text('View all'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _MaintenancePreviewList(
                                  docs: generalDocs.take(4).toList(),
                                  onUpdateStatus: (doc, status) =>
                                      _updateTicketStatus(
                                        doc: doc,
                                        nextStatus: status,
                                        actorName: profile.name,
                                      ),
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

class _CaretakerSummaryCard extends StatelessWidget {
  const _CaretakerSummaryCard({
    required this.propertyName,
    required this.openTasks,
    required this.visitorsInside,
    required this.totalLogs,
  });

  final String propertyName;
  final int openTasks;
  final int visitorsInside;
  final int totalLogs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                label: 'Open tasks',
                value: '$openTasks',
                highlight: openTasks > 0,
              ),
              _DarkMetric(label: 'Visitors inside', value: '$visitorsInside'),
              _DarkMetric(label: 'Total logs', value: '$totalLogs'),
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
            'New $roleTitle Assignment: $propName',
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

class _MaintenancePreviewList extends StatelessWidget {
  const _MaintenancePreviewList({
    required this.docs,
    required this.onUpdateStatus,
  });

  final _DocList docs;
  final void Function(DocumentSnapshot doc, String status) onUpdateStatus;

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
            'No maintenance or plumbing requests yet.',
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
              final title = (d['title'] ?? 'Maintenance Issue').toString();
              final desc = (d['description'] ?? '').toString();
              final unitName = (d['unitName'] ?? 'Common Area').toString();
              final category = (d['category'] ?? 'general').toString();
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
                      '$unitName • ${category.toUpperCase()}',
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
          ),
      ],
    );
  }
}

class _CaretakerMaintenanceList extends StatelessWidget {
  final String propertyId;
  final void Function(DocumentSnapshot doc, String status) onUpdateStatus;

  const _CaretakerMaintenanceList({
    required this.propertyId,
    required this.onUpdateStatus,
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
          return (d['category'] ?? 'general') != 'electrical';
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'All Maintenance Tickets',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _MaintenancePreviewList(docs: docs, onUpdateStatus: onUpdateStatus),
          ],
        );
      },
    );
  }
}

class _CaretakerVisitorSheet extends StatelessWidget {
  final String propertyId;
  final VoidCallback onAddVisitor;

  const _CaretakerVisitorSheet({
    required this.propertyId,
    required this.onAddVisitor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visitorLogs')
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
                  'Visitor & Delivery Log',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAddVisitor();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Check In'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No visitor entries logged yet.')),
              ),
            for (final doc in docs)
              Builder(
                builder: (context) {
                  final d = doc.data() as JsonMap? ?? <String, dynamic>{};
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
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isInside
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          child: Icon(
                            isInside
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            color: isInside
                                ? Colors.green.shade800
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name → $unit',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
              ),
          ],
        );
      },
    );
  }
}
