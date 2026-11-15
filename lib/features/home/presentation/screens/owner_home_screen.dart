// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/owner_tenants_provider.dart';

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

class _NoticePropertyOption {
  const _NoticePropertyOption({
    required this.id,
    required this.name,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String ownerId;
}

class OwnerHomeScreen extends ConsumerWidget {
  const OwnerHomeScreen({super.key});

  void _openMaintenanceSheet(BuildContext context, String ownerId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OwnerMaintenanceSheet(
        filterField: 'ownerId',
        filterValues: [ownerId],
      ),
    );
  }

  void _openNoticesSheet(
    BuildContext context,
    String uid,
    String userName,
    List<Property> properties,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OwnerNoticesSheet(
        actorUid: uid,
        actorName: userName,
        properties: properties
            .map(
              (p) => _NoticePropertyOption(
                id: p.id,
                name: p.name,
                ownerId: p.ownerId,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final properties =
        ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[];
    final theme = Theme.of(context);

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
                Icons.apartment_rounded,
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
                  'Owner Console',
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
        error: (error, stackTrace) => _ErrorView(
          message: 'Unable to load owner account information.',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'Owner profile not found.',
              onRetry: () => ref.invalidate(currentUserProfileProvider),
            );
          }

          final ownedProps = properties
              .where((p) => p.ownerId == profile.uid)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(currentOwnerPropertiesProvider);
              ref.invalidate(ownerTenantsProvider);
              await ref.read(currentUserProfileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                _Header(name: profile.name, publicId: profile.publicId),
                const SizedBox(height: 16),

                _OpenIssuesBanner(
                  filterField: 'ownerId',
                  filterValues: [profile.uid],
                  onTap: () => _openMaintenanceSheet(context, profile.uid),
                ),

                const _SummaryCard(),
                const SizedBox(height: 14),
                const _PrimaryActions(),
                const SizedBox(height: 22),
                const _SectionTitle('Your team'),
                const SizedBox(height: 10),
                const _TeamCard(),
                const SizedBox(height: 22),
                const _SectionTitle('Quick actions'),
                const SizedBox(height: 10),
                _ManageGrid(
                  onOpenIssues: () =>
                      _openMaintenanceSheet(context, profile.uid),
                  onOpenNotices: () => _openNoticesSheet(
                    context,
                    profile.uid,
                    profile.name,
                    ownedProps,
                  ),
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  'Buildings',
                  trailing: TextButton(
                    onPressed: () => context.push(RouteNames.propertyList),
                    child: const Text('View all'),
                  ),
                ),
                const SizedBox(height: 6),
                const _BuildingsStrip(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.ownerHome),
        onMoreTap: () => context.push(RouteNames.more),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.publicId});

  final String name;
  final String publicId;

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
                  content: Text('Owner ID copied.'),
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

class _OpenIssuesBanner extends StatelessWidget {
  const _OpenIssuesBanner({
    required this.filterField,
    required this.filterValues,
    required this.onTap,
  });

  final String filterField;
  final List<String> filterValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (filterValues.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final query = filterField == 'ownerId'
        ? FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('ownerId', isEqualTo: filterValues.first)
        : FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('propertyId', whereIn: filterValues.take(10).toList());

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot>[];

        final openCount = docs.where((d) {
          final s = (_asMap(d.data())['status'] ?? 'open').toString();
          return s == 'open' || s == 'in_progress';
        }).length;

        if (openCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.report_problem_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                openCount == 1
                    ? '1 tenant maintenance issue open'
                    : '$openCount tenant maintenance issues open',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              subtitle: Text(
                'Tap to review, assign or mark resolved',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}

class _OwnerMaintenanceSheet extends StatelessWidget {
  const _OwnerMaintenanceSheet({
    required this.filterField,
    required this.filterValues,
  });

  final String filterField;
  final List<String> filterValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final query = filterField == 'ownerId'
        ? FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('ownerId', isEqualTo: filterValues.first)
        : FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('propertyId', whereIn: filterValues.take(10).toList());

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...snap.data!.docs];

            docs.sort((a, b) {
              final at = _asMap(a.data())['createdAt'];
              final bt = _asMap(b.data())['createdAt'];

              final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;

              return bm.compareTo(am);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text(
                  'Maintenance & Tenant Issues',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No issues reported yet.')),
                  ),
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final d = _asMap(doc.data());

                      final title = (d['title'] ?? 'Issue').toString();
                      final desc = (d['description'] ?? '').toString();
                      final prop = (d['propertyName'] ?? '').toString();
                      final unit = (d['unitName'] ?? '').toString();
                      final cat = (d['category'] ?? 'general').toString();
                      final status = (d['status'] ?? 'open').toString();
                      final tenantName = (d['tenantName'] ?? '').toString();

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
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (tenantName.isNotEmpty)
                                Text(
                                  'Reported by: $tenantName',
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(desc, style: theme.textTheme.bodySmall),
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
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// OWNER BUILDING NOTICES SHEET
// ============================================================================

class _OwnerNoticesSheet extends StatefulWidget {
  const _OwnerNoticesSheet({
    required this.actorUid,
    required this.actorName,
    required this.properties,
  });

  final String actorUid;
  final String actorName;
  final List<_NoticePropertyOption> properties;

  @override
  State<_OwnerNoticesSheet> createState() => _OwnerNoticesSheetState();
}

class _OwnerNoticesSheetState extends State<_OwnerNoticesSheet> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  late String _selectedPropertyId;
  String _priority = 'normal';
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.properties.isNotEmpty
        ? widget.properties.first.id
        : '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishNotice() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (_selectedPropertyId.isEmpty || title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building and enter title & message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prop = widget.properties.firstWhere(
      (p) => p.id == _selectedPropertyId,
      orElse: () => widget.properties.first,
    );

    setState(() => _posting = true);
    try {
      await FirebaseFirestore.instance.collection('buildingNotices').add({
        'ownerId': widget.actorUid,
        'propertyId': prop.id,
        'propertyName': prop.name,
        'title': title,
        'message': message,
        'priority': _priority,
        'postedByUid': widget.actorUid,
        'postedByName': widget.actorName,
        'postedByRole': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _messageCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice published to residents!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish notice: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.properties.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Add a building first to post notices.')),
        ),
      );
    }

    final activePropId =
        widget.properties.any((p) => p.id == _selectedPropertyId)
        ? _selectedPropertyId
        : widget.properties.first.id;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Building Notices',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Post announcements directly to residents of your building.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (widget.properties.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: activePropId,
                  decoration: const InputDecoration(
                    labelText: 'Target Building',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.properties
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPropertyId = v);
                  },
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notice Title *',
                  hintText: 'e.g. Water Tank Cleaning Tomorrow',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details / Schedule *',
                  hintText: 'Water supply will be paused from 10 AM to 1 PM.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Urgency Level',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'important',
                          child: Text('Important'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _priority = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onPressed: _posting ? null : _publishNotice,
                    icon: _posting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Publish'),
                  ),
                ],
              ),
              const Divider(height: 28),
              const Text(
                'Published Notices',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buildingNotices')
                    .where('propertyId', isEqualTo: activePropId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = [...snap.data!.docs];
                  docs.sort((a, b) {
                    final at = _asMap(a.data())['createdAt'];
                    final bt = _asMap(b.data())['createdAt'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });

                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No notices posted for this building yet.',
                          style: TextStyle(
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
                            final d = _asMap(doc.data());
                            final isUrgent =
                                (d['priority'] ?? 'normal') == 'urgent';
                            final postedBy = (d['postedByName'] ?? 'Admin')
                                .toString();
                            final roleLabel = (d['postedByRole'] ?? 'owner')
                                .toString()
                                .toUpperCase();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isUrgent
                                      ? Icons.priority_high_rounded
                                      : Icons.campaign_outlined,
                                  color: isUrgent
                                      ? Colors.red
                                      : theme.colorScheme.primary,
                                ),
                                title: Text(
                                  (d['title'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${d['message'] ?? ''}\nBy $postedBy ($roleLabel)',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Delete notice',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => doc.reference.delete(),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserProfileProvider).value?.uid;
    final db = FirebaseFirestore.instance;

    final rates = uid == null
        ? const Stream<QuerySnapshot>.empty()
        : db
              .collection('rentRates')
              .where('ownerId', isEqualTo: uid)
              .snapshots();

    final bills = uid == null
        ? const Stream<QuerySnapshot>.empty()
        : db
              .collection('monthlyBills')
              .where('ownerId', isEqualTo: uid)
              .snapshots();

    final properties =
        ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[];

    final owned = properties.where((p) => p.ownerId == uid).length;

    final tenants = ref.watch(ownerTenantsProvider).value ?? const <Tenant>[];

    final activeTenants = tenants
        .where((t) => t.status == TenantStatus.active)
        .length;

    return StreamBuilder<QuerySnapshot>(
      stream: rates,
      builder: (context, ratesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: bills,
          builder: (context, billsSnap) {
            var rent = 0.0;

            for (final d
                in ratesSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final m = _asMap(d.data());

              if (m['effectiveTo'] == null && m['amount'] is num) {
                rent += (m['amount'] as num).toDouble();
              }
            }

            var unsettled = 0;

            for (final d
                in billsSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final m = _asMap(d.data());
              final s = (m['status'] ?? 'unpaid').toString();

              if (s != 'paid' && s != 'cancelled') {
                unsettled++;
              }
            }

            final rentText = rent == rent.roundToDouble()
                ? rent.toStringAsFixed(0)
                : rent.toStringAsFixed(2);

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
                  Text(
                    'Expected rent this month',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳ $rentText',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(label: 'Buildings', value: '$owned'),
                      _Stat(label: 'Residents', value: '$activeTenants'),
                      _Stat(
                        label: 'Unpaid bills',
                        value: '$unsettled',
                        highlight: unsettled > 0,
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
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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

class _PrimaryActions extends ConsumerWidget {
  const _PrimaryActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => context.push(RouteNames.addTenant),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text('Add resident'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await context.push(RouteNames.addProperty);
              if (!context.mounted) return;
              ref.invalidate(currentOwnerPropertiesProvider);
            },
            icon: const Icon(Icons.add_home_work_rounded, size: 20),
            label: const Text('Add building'),
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends ConsumerWidget {
  const _TeamCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final managers =
        ref.watch(ownerManagersProvider).value ?? const <TeamMember>[];

    final staff = ref.watch(ownerStaffProvider).value ?? const <TeamMember>[];

    final pending =
        (ref.watch(ownerPendingManagerInvitesProvider).value ??
                const <TeamMember>[])
            .length +
        (ref.watch(ownerPendingStaffInvitesProvider).value ??
                const <TeamMember>[])
            .length;

    final orders =
        ref.watch(ownerWorkOrdersProvider).value ?? const <WorkOrder>[];

    int active(Iterable<TeamMember> l, [String? role]) => l
        .where((m) => m.status == 'active' && (role == null || m.role == role))
        .length;

    final suspended = [
      ...managers,
      ...staff,
    ].where((m) => m.status == 'suspended').length;

    final openTasks = orders.where((w) => w.isOpenish).length;

    final notes = <String>[
      if (pending > 0) '$pending pending invite${pending == 1 ? '' : 's'}',
      if (suspended > 0) '$suspended suspended',
      if (openTasks > 0) '$openTasks open task${openTasks == 1 ? '' : 's'}',
    ];

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RouteNames.ownerTeam),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TeamCount(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Managers',
                    count: active(managers),
                    color: Colors.indigo,
                  ),
                  _TeamCount(
                    icon: Icons.handyman_rounded,
                    label: 'Caretakers',
                    count: active(staff, 'caretaker'),
                    color: Colors.teal,
                  ),
                  _TeamCount(
                    icon: Icons.electrical_services_rounded,
                    label: 'Electricians',
                    count: active(staff, 'electrician'),
                    color: Colors.amber.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notes.isEmpty
                          ? 'Invite people, manage access and assign work.'
                          : notes.join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: notes.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        fontWeight: notes.isEmpty
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamCount extends StatelessWidget {
  const _TeamCount({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageGrid extends StatelessWidget {
  const _ManageGrid({required this.onOpenIssues, required this.onOpenNotices});

  final VoidCallback onOpenIssues;
  final VoidCallback onOpenNotices;

  @override
  Widget build(BuildContext context) {
    final items = <_GridItem>[
      _GridItem(
        Icons.groups_rounded,
        'Residents',
        'Tenants & leases',
        Colors.teal,
        () => context.push(RouteNames.ownerTenants),
      ),
      _GridItem(
        Icons.domain_rounded,
        'Buildings',
        'Units & floors',
        Colors.indigo,
        () => context.push(RouteNames.propertyList),
      ),
      _GridItem(
        Icons.payments_outlined,
        'Payments',
        'Review & confirm',
        Colors.green,
        () => context.push(RouteNames.ownerPayments),
      ),
      _GridItem(
        Icons.build_circle_outlined,
        'Issues',
        'Tenant complaints',
        Colors.deepOrange,
        onOpenIssues,
      ),
      _GridItem(
        Icons.campaign_outlined,
        'Notices',
        'Post & manage',
        Colors.amber.shade800,
        onOpenNotices,
      ),
      _GridItem(
        Icons.price_change_outlined,
        'Rent control',
        'Change rates',
        Colors.deepPurpleAccent,
        () => context.push(RouteNames.centralRentControl),
      ),
      _GridItem(
        Icons.receipt_long_rounded,
        'Billing rules',
        'Utilities & charges',
        Colors.brown,
        () => context.push(RouteNames.ownerBillingRules),
      ),
      _GridItem(
        Icons.history_edu_rounded,
        'Audit trail',
        'Activity logs',
        Colors.blueGrey,
        () => context.push(RouteNames.activityLogs),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [for (final i in items) _GridTile(item: i)],
    );
  }
}

class _GridItem {
  const _GridItem(this.icon, this.title, this.subtitle, this.color, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.item});

  final _GridItem item;

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
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      item.subtitle,
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

class _BuildingsStrip extends ConsumerWidget {
  const _BuildingsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserProfileProvider).value?.uid;

    return ref
        .watch(currentOwnerPropertiesProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Unable to load buildings: $e'),
          data: (all) {
            final owned = uid == null
                ? all
                : all.where((p) => p.ownerId == uid).toList();

            if (owned.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.domain_disabled_rounded,
                      size: 38,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No buildings yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add your first building to start managing units and tenants.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: owned.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _BuildingCard(property: owned[i]),
              ),
            );
          },
        );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = property.status == PropertyStatus.active;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          RouteNames.propertyDetails.replaceFirst(':propertyId', property.id),
        ),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (active ? Colors.green : Colors.orange).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                property.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                '${property.numberOfFloors} floors • ${property.propertyCode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        ?trailing,
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
