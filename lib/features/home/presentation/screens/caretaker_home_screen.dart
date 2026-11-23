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

class CaretakerHomeScreen extends ConsumerStatefulWidget {
  const CaretakerHomeScreen({super.key});

  @override
  ConsumerState<CaretakerHomeScreen> createState() =>
      _CaretakerHomeScreenState();
}

class _CaretakerHomeScreenState extends ConsumerState<CaretakerHomeScreen> {
  bool _busy = false;
  String? _selectedPropertyId;

  Future<HomeDocList>? _invitesFuture;
  String? _cachedForUid;

  Stream<QuerySnapshot>? _accessStream;
  String? _accessStreamUid;

  String? _activeStreamsPropId;
  Stream<QuerySnapshot> _issuesStream = const Stream<QuerySnapshot>.empty();
  Stream<QuerySnapshot> _visitorsStream = const Stream<QuerySnapshot>.empty();

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
          .where('staffRole', isEqualTo: 'caretaker')
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
    _issuesStream = db
        .collection('maintenanceRequests')
        .where('propertyId', isEqualTo: propertyId)
        .limit(50)
        .snapshots();
    _visitorsStream = db
        .collection('visitorLogs')
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
        staffRole: 'caretaker',
      );
    }
    return _invitesFuture!;
  }

  void _refreshInvites(dynamic profile) {
    setState(() {
      _cachedForUid = profile.uid.toString().trim();
      _invitesFuture = GrihoStaffInviteService.fetchPendingStaffInvites(
        profile: profile,
        staffRole: 'caretaker',
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
        staffRole: 'caretaker',
        accept: accept,
      );
      AuthRouteGuard.clearAccessCache();
      ref.invalidate(currentUserProfileProvider);

      if (!mounted) {
        return;
      }
      _refreshInvites(profile);
      if (accept) {
        GrihoFeedback.showSuccess(context, 'Caretaker assignment accepted!');
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

  Future<void> _updateTicketStatus({
    required DocumentSnapshot doc,
    required String nextStatus,
    required String actorName,
  }) async {
    final data = homeAsMap(doc.data());
    String note = '';

    if (nextStatus == 'resolved') {
      final noteCtrl = TextEditingController();
      final confirmedNote = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark Issue Resolved'),
          content: GrihoTextField(
            controller: noteCtrl,
            label: 'Resolution Note (Optional)',
            hint: 'e.g. Pipe leak repaired and tested',
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      noteCtrl.dispose();
      if (confirmedNote == null) {
        return;
      }
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

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        'Ticket updated to ${nextStatus.replaceAll('_', ' ')}.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Unable to update ticket: $e');
    }
  }

  Future<void> _showAddVisitorDialog({
    required HomeJsonMap activeAssignment,
    required dynamic profile,
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Log New Visitor / Delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrihoTextField(
                  controller: nameCtrl,
                  label: 'Visitor Name *',
                  prefixIcon: Iconsax.user,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: phoneCtrl,
                  label: 'Visitor Phone',
                  prefixIcon: Iconsax.call,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: unitCtrl,
                  label: 'Target Unit / Floor *',
                  hint: 'e.g. Unit 3B',
                  prefixIcon: Iconsax.home_2,
                ),
                const SizedBox(height: 12),
                GrihoTextField(
                  controller: purposeCtrl,
                  label: 'Purpose / Delivery Details',
                  hint: 'e.g. Guest / Parcel Delivery',
                  prefixIcon: Iconsax.clipboard_text,
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

      if (saved != true || !mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(context, 'Visitor checked in successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Failed to log visitor: $e');
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      unitCtrl.dispose();
      purposeCtrl.dispose();
    }
  }

  Future<void> _showPostNoticeDialog({
    required HomeJsonMap activeAssignment,
    required dynamic profile,
  }) async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String priority = 'normal';

    try {
      final posted = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Post Building Notice'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GrihoTextField(
                    controller: titleCtrl,
                    label: 'Notice Title *',
                    hint: 'e.g. Water Tank Cleaning Tomorrow',
                    prefixIcon: Iconsax.notification_bing,
                  ),
                  const SizedBox(height: 12),
                  GrihoTextField(
                    controller: messageCtrl,
                    label: 'Details / Schedule *',
                    hint: 'Water supply will be paused from 10 AM to 1 PM.',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(
                      labelText: 'Urgency Level',
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
                      if (v != null) {
                        setDialogState(() => priority = v);
                      }
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

      if (posted != true || !mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(context, 'Building notice published.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Failed to publish notice: $e');
    } finally {
      titleCtrl.dispose();
      messageCtrl.dispose();
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

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: const GrihoHomeAppBar(consoleLabel: 'Caretaker Console'),
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
                                      'New Caretaker Assignment: ${d['propertyName'] ?? 'Building'}',
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
                            icon: Iconsax.setting_2,
                            title: 'No Active Building Assignment',
                            subtitle:
                                'Share your Griho ID (${profile.publicId}) or Phone (${profile.phoneNumber}) with the property owner to receive a Caretaker assignment.',
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
                    stream: _issuesStream,
                    builder: (context, issuesSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _visitorsStream,
                        builder: (context, visitorsSnap) {
                          final generalDocs = (issuesSnap.data?.docs ?? [])
                              .where((doc) {
                                final d = homeAsMap(doc.data());
                                return (d['category'] ?? 'general') !=
                                    'electrical';
                              })
                              .toList();

                          final openTasks = generalDocs.where((doc) {
                            final d = homeAsMap(doc.data());
                            final s = (d['status'] ?? 'open').toString();
                            return s == 'open' || s == 'in_progress';
                          }).toList();

                          final visitorDocs = visitorsSnap.data?.docs ?? [];
                          final insideVisitorsCount = visitorDocs.where((doc) {
                            final d = homeAsMap(doc.data());
                            return (d['status'] ?? 'checked_in') ==
                                'checked_in';
                          }).length;

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
                                            'New Caretaker Assignment: ${d['propertyName'] ?? 'Building'}',
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
                                      label: 'Open tasks',
                                      value: '${openTasks.length}',
                                      highlight: openTasks.isNotEmpty,
                                    ),
                                    GrihoHeroMetric(
                                      label: 'Visitors inside',
                                      value: '$insideVisitorsCount',
                                    ),
                                    GrihoHeroMetric(
                                      label: 'Total logs',
                                      value: '${visitorDocs.length}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GrihoPrimaryButton(
                                        label: 'Log visitor',
                                        icon: Iconsax.user_add,
                                        onPressed: () => _showAddVisitorDialog(
                                          activeAssignment: currentAssignment,
                                          profile: profile,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GrihoSecondaryButton(
                                        label: 'Post notice',
                                        icon: Iconsax.notification_bing,
                                        onPressed: () => _showPostNoticeDialog(
                                          activeAssignment: currentAssignment,
                                          profile: profile,
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
                                      icon: Iconsax.setting_2,
                                      title: 'Maintenance',
                                      subtitle: '${openTasks.length} open',
                                      color: Colors.deepOrange,
                                      onTap: () => _openMaintenanceSheet(
                                        activePropertyId,
                                        profile.name,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.personalcard,
                                      title: 'Visitor log',
                                      subtitle: '$insideVisitorsCount inside',
                                      color: GrihoColors.emerald,
                                      onTap: () => _openVisitorSheet(
                                        activePropertyId,
                                        currentAssignment,
                                        profile,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.notification_bing,
                                      title: 'Post notice',
                                      subtitle: 'Alert residents',
                                      color: GrihoColors.warning,
                                      onTap: () => _showPostNoticeDialog(
                                        activeAssignment: currentAssignment,
                                        profile: profile,
                                      ),
                                    ),
                                    GrihoQuickActionItem(
                                      icon: Iconsax.document_text,
                                      title: 'Notice board',
                                      subtitle: 'View all notices',
                                      color: Colors.indigo,
                                      onTap: () =>
                                          context.go(RouteNames.notices),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                GrihoSectionHeader(
                                  'Maintenance tasks',
                                  trailing: generalDocs.isNotEmpty
                                      ? TextButton(
                                          onPressed: () =>
                                              _openMaintenanceSheet(
                                                activePropertyId,
                                                profile.name,
                                              ),
                                          child: const Text('View all'),
                                        )
                                      : null,
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

class _MaintenancePreviewList extends StatelessWidget {
  const _MaintenancePreviewList({
    required this.docs,
    required this.onUpdateStatus,
  });

  final HomeDocList docs;
  final void Function(DocumentSnapshot doc, String status) onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (docs.isEmpty) {
      return const GrihoStatusState(
        icon: Iconsax.tick_circle,
        title: 'All caught up',
        subtitle: 'No maintenance or plumbing requests yet.',
      );
    }

    return Column(
      children: [
        for (final doc in docs)
          Builder(
            builder: (context) {
              final d = homeAsMap(doc.data());
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
                          if (status == 'open') ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    onUpdateStatus(doc, 'in_progress'),
                                child: const Text('Start Work'),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
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
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const GrihoLoadingView(message: 'Loading tickets...');
        }
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final d = homeAsMap(doc.data());
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
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const GrihoLoadingView(message: 'Loading visitor log...');
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
                  icon: const Icon(Iconsax.add, size: 18),
                  label: const Text('Check In'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: GrihoStatusState(
                  icon: Iconsax.personalcard,
                  title: 'No visitor entries yet',
                  subtitle: 'Check in guests or parcel deliveries here.',
                ),
              ),
            for (final doc in docs)
              Builder(
                builder: (context) {
                  final d = homeAsMap(doc.data());
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
                              ? GrihoColors.emerald.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            isInside ? Iconsax.login : Iconsax.logout,
                            size: 18,
                            color: isInside
                                ? GrihoColors.emerald
                                : theme.colorScheme.onSurfaceVariant,
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
                          Text(
                            'LEFT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
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
