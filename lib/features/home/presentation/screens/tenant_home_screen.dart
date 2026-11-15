import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../billing/presentation/widgets/tenant_current_bills_card.dart';
import '../../../invitations/presentation/providers/work_invitations_providers.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../../tenants/presentation/screens/tenant_tenancy_history_screen.dart';

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends ConsumerState<TenantHomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(tenantDashboardProvider);
    await ref.read(tenantDashboardProvider.future);
  }

  void _openInvitation(TenantInvitation invitation) {
    context.push(RouteNames.tenantInvitationPath(invitation.id));
  }

  void _openInvitations() => context.push(RouteNames.tenantInvitations);

  void _openPayments() => context.push(RouteNames.tenantPayments);

  void _openTenancyHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TenantTenancyHistoryScreen()),
    );
  }

  void _reportIssue(TenantDashboardData d) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportIssueSheet(dashboard: d),
    );
  }

  void _openMyRequests() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _MyRequestsSheet(),
    );
  }

  void _openNotices(TenantDashboardData d) {
    final propertyId = d.tenant?.propertyId.trim() ?? '';
    if (propertyId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoticesSheet(propertyId: propertyId),
    );
  }

  void _copyId(String publicId) {
    if (publicId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: publicId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Griho ID copied.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tenantDashboardProvider);
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
                  'Resident Portal',
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
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _DashboardErrorView(error: error, onRetry: _refresh),
        data: (dashboard) {
          final publicId = dashboard.appUser?.publicId ?? '';
          final active = dashboard.hasActiveTenancy;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                _Header(dashboard: dashboard, onCopy: () => _copyId(publicId)),
                const SizedBox(height: 16),

                if (dashboard.hasPendingInvitation) ...[
                  _PendingInvitationCard(
                    invitation: dashboard.pendingInvitation!,
                    onReview: () =>
                        _openInvitation(dashboard.pendingInvitation!),
                  ),
                  const SizedBox(height: 16),
                ],

                Consumer(
                  builder: (context, ref, _) {
                    final n =
                        ref
                            .watch(pendingWorkInvitationsProvider)
                            .value
                            ?.length ??
                        0;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const Icon(Icons.work_outline_rounded),
                          title: Text(
                            n == 1
                                ? '1 work invitation'
                                : '$n work invitations',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Manager / caretaker / electrician offer',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await context.push(RouteNames.myInvitations);
                            ref.invalidate(pendingWorkInvitationsProvider);
                          },
                        ),
                      ),
                    );
                  },
                ),

                if (active)
                  _DigitalResidencyPass(dashboard: dashboard)
                else
                  _NoActiveTenancyPassport(
                    userPublicId: publicId,
                    hasPendingInvitation: dashboard.hasPendingInvitation,
                    onOpenInvitations: _openInvitations,
                  ),

                if (active) ...[
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Bills & dues',
                    trailing: TextButton(
                      onPressed: _openPayments,
                      child: const Text('Payments'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const TenantCurrentBillsCard(),
                ],

                const SizedBox(height: 22),
                const _SectionHeader(title: 'Quick actions'),
                const SizedBox(height: 10),
                _ActionGrid(
                  items: [
                    if (active)
                      _ActionItem(
                        Icons.payments_outlined,
                        'Payments',
                        'Pay & receipts',
                        Colors.green,
                        _openPayments,
                      ),
                    if (active)
                      _ActionItem(
                        Icons.report_problem_outlined,
                        'Report issue',
                        'Plumbing, electric…',
                        Colors.deepOrange,
                        () => _reportIssue(dashboard),
                      ),
                    if (active)
                      _ActionItem(
                        Icons.build_circle_outlined,
                        'My requests',
                        'Track repairs',
                        Colors.indigo,
                        _openMyRequests,
                      ),
                    if (active)
                      _ActionItem(
                        Icons.campaign_outlined,
                        'Notices',
                        'From your building',
                        Colors.amber.shade800,
                        () => _openNotices(dashboard),
                      ),
                    _ActionItem(
                      Icons.mark_email_read_outlined,
                      'Invitations',
                      'Lease offers',
                      Colors.blueAccent,
                      _openInvitations,
                    ),
                    _ActionItem(
                      Icons.history_rounded,
                      'History',
                      'Past stays',
                      Colors.teal,
                      _openTenancyHistory,
                    ),
                    _ActionItem(
                      Icons.share_rounded,
                      'Share ID',
                      'Copy your Griho ID',
                      Colors.deepPurpleAccent,
                      () => _copyId(publicId),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                const _SectionHeader(title: 'Recent activity'),
                const SizedBox(height: 10),
                _RecentActivityCard(dashboard: dashboard),

                if (dashboard.hasTenancyHistory) ...[
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Past residences',
                    trailing: TextButton(
                      onPressed: _openTenancyHistory,
                      child: const Text('View all'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TenancyHistoryPreview(
                    history: dashboard.tenancyHistory,
                    onViewItem: _openTenancyHistory,
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.tenantHome),
        onMoreTap: () => context.push(RouteNames.more),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.dashboard, required this.onCopy});

  final TenantDashboardData dashboard;
  final VoidCallback onCopy;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final publicId = dashboard.appUser?.publicId ?? '';

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
                dashboard.displayName,
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
            onPressed: onCopy,
          ),
      ],
    );
  }
}

// ============================================================================
// ACTION GRID
// ============================================================================

class _ActionItem {
  const _ActionItem(
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

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.items});

  final List<_ActionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        for (final i in items)
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: i.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: i.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(i.icon, size: 20, color: i.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            i.subtitle,
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
          ),
      ],
    );
  }
}

// ============================================================================
// REPORT ISSUE  ->  maintenanceRequests (owner assigns, caretaker/electrician resolve)
// ============================================================================

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({required this.dashboard});

  final TenantDashboardData dashboard;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'plumbing';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final d = widget.dashboard;
    final tenant = d.tenant;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final title = _titleCtrl.text.trim();

    if (tenant == null || uid == null) return;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the problem.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('maintenanceRequests').add({
        'ownerId': tenant.ownerId,
        'propertyId': tenant.propertyId,
        'propertyName': d.currentPropertyName ?? '',
        'unitName': d.currentUnitDisplayName ?? 'Unit',
        'tenantUserId': uid,
        'tenantName': d.displayName,
        'title': title,
        'description': _descCtrl.text.trim(),
        'category': _category,
        'status': 'open',
        'assignedToUid': '',
        'assignedToName': '',
        'assignedRole': '',
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent to your building team.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send request: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Report an issue',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.dashboard.currentPropertyName ?? ''} • ${widget.dashboard.currentUnitDisplayName ?? ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'plumbing',
                  label: Text('Plumbing'),
                  icon: Icon(Icons.water_drop_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 'electrical',
                  label: Text('Electric'),
                  icon: Icon(Icons.bolt_rounded, size: 18),
                ),
                ButtonSegment(
                  value: 'general',
                  label: Text('Other'),
                  icon: Icon(Icons.build_outlined, size: 18),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (v) => setState(() => _category = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is the problem? *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MY REQUESTS
// ============================================================================

class _MyRequestsSheet extends StatelessWidget {
  const _MyRequestsSheet();

  Color _color(String s) {
    switch (s) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _label(String s) => s == 'in_progress'
      ? 'In progress'
      : (s.isEmpty ? 'Open' : s[0].toUpperCase() + s.substring(1));

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: uid == null
            ? const Center(child: Text('Please sign in again.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('maintenanceRequests')
                    .where('tenantUserId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Unable to load: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = [...snap.data!.docs];
                  docs.sort((a, b) {
                    final at = a.data()['createdAt'];
                    final bt = b.data()['createdAt'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      const Text(
                        'My requests',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No requests yet.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      for (final doc in docs)
                        Builder(
                          builder: (context) {
                            final d = doc.data();
                            final status = (d['status'] ?? 'open').toString();
                            final note = (d['resolutionNote'] ?? '').toString();
                            final color = _color(status);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(
                                  (d['title'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  note.isEmpty
                                      ? (d['category'] ?? '').toString()
                                      : note,
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _label(status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
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
// BUILDING NOTICES
// ============================================================================

class _NoticesSheet extends StatelessWidget {
  const _NoticesSheet({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('buildingNotices')
              .where('propertyId', isEqualTo: propertyId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Unable to load: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...snap.data!.docs];
            docs.sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bm.compareTo(am);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                const Text(
                  'Building notices',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No notices right now.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final d = doc.data();
                      final urgent =
                          (d['priority'] ?? '').toString() == 'high' ||
                          (d['priority'] ?? '').toString() == 'urgent';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(
                            urgent
                                ? Icons.priority_high_rounded
                                : Icons.campaign_outlined,
                            color: urgent
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          title: Text(
                            (d['title'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text((d['message'] ?? '').toString()),
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
// 2. HERO DIGITAL RESIDENCY PASS (KEYCARD)
// ============================================================================

class _DigitalResidencyPass extends ConsumerWidget {
  final TenantDashboardData dashboard;

  const _DigitalResidencyPass({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final propertyName = dashboard.currentPropertyName ?? 'Assigned Property';
    final unitDisplayName = dashboard.currentUnitDisplayName ?? 'Unit';
    final tenant = dashboard.tenant;
    final unitId = tenant?.unitId.trim();
    final hasValidUnitId = unitId != null && unitId.isNotEmpty;
    final rentAsync = hasValidUnitId
        ? ref.watch(currentTenantRentRateProvider(unitId))
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2232), Color(0xFF131722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow Element
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DIGITAL RESIDENCY PASS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: Colors.greenAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Active Stay',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Property & Unit Title
                Text(
                  propertyName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.door_front_door_outlined,
                      size: 16,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unitDisplayName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 14),

                // Financial & Occupancy Sub-Metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agreed Monthly Rent',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        rentAsync == null
                            ? const Text(
                                '—',
                                style: TextStyle(color: Colors.white),
                              )
                            : rentAsync.when(
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white70,
                                  ),
                                ),
                                error: (_, _) => const Text(
                                  'Not set',
                                  style: TextStyle(color: Colors.white),
                                ),
                                data: (rent) => Text(
                                  rent != null
                                      ? '৳ ${_formatAmount(rent.amount)}'
                                      : 'Not Set',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Moved In',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tenant?.tenancyStartedAt != null
                              ? _formatDate(tenant!.tenancyStartedAt!)
                              : 'Recent',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. PENDING INVITATION BANNER
// ============================================================================

class _PendingInvitationCard extends StatelessWidget {
  final TenantInvitation invitation;
  final VoidCallback onReview;

  const _PendingInvitationCard({
    required this.invitation,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyName = invitation.propertyName?.trim() ?? 'Assigned Property';
    final unitName = invitation.unitNumber?.trim() ?? 'Designated Unit';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onTertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_rounded,
                  size: 18,
                  color: theme.colorScheme.tertiaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Tenancy Invitation Received',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Action Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You are invited to finalize lease terms for "$propertyName" ($unitName) with agreed monthly rent of ৳ ${_formatAmount(invitation.rentAmount)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onTertiaryContainer,
                foregroundColor: theme.colorScheme.tertiaryContainer,
              ),
              onPressed: onReview,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Review & Accept Invitation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. DIGITAL TENANT PASSPORT (EMPTY RESIDENCY STATE)
// ============================================================================

class _NoActiveTenancyPassport extends StatelessWidget {
  final String userPublicId;
  final bool hasPendingInvitation;
  final VoidCallback onOpenInvitations;

  const _NoActiveTenancyPassport({
    required this.userPublicId,
    required this.hasPendingInvitation,
    required this.onOpenInvitations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasPendingInvitation
                    ? Icons.mark_email_unread_rounded
                    : Icons.home_work_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasPendingInvitation
                  ? 'Awaiting Tenancy Acceptance'
                  : 'Ready to Move In?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasPendingInvitation
                  ? 'You have received a new tenancy offer. Review the details above to activate your tenancy.'
                  : 'Share your Griho Public ID with your property manager or landlord to receive your unit onboarding invitation.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (userPublicId.isNotEmpty && !hasPendingInvitation) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR GRIHO ID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userPublicId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userPublicId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Griho ID copied to clipboard.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy ID'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. RECENT ACTIVITY TIMELINE
// ============================================================================

class _RecentActivityCard extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _RecentActivityCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = _buildActivities(dashboard);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < activities.length; index++) ...[
              _ActivityItem(activity: activities[index]),
              if (index != activities.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  List<_ActivityData> _buildActivities(TenantDashboardData dashboard) {
    final activities = <_ActivityData>[];
    final invitation = dashboard.pendingInvitation;
    if (invitation != null && invitation.isPending && !invitation.isExpired) {
      activities.add(
        _ActivityData(
          icon: Icons.mail_outline_rounded,
          title: 'Invitation Received',
          subtitle: invitation.propertyName ?? 'New unit tenancy offered',
          date: invitation.createdAt,
        ),
      );
    }

    final tenant = dashboard.tenant;
    if (tenant != null &&
        tenant.status == TenantStatus.active &&
        tenant.tenancyStartedAt != null) {
      activities.add(
        _ActivityData(
          icon: Icons.key_rounded,
          title: 'Moved in to New Space',
          subtitle: dashboard.currentPropertyName ?? 'Tenancy active',
          date: tenant.tenancyStartedAt!,
        ),
      );
    }

    for (final history in dashboard.tenancyHistory.take(2)) {
      activities.add(
        _ActivityData(
          icon: Icons.history_rounded,
          title: 'Tenancy Concluded',
          subtitle: history.propertyName,
          date: history.endedAt,
        ),
      );
    }

    activities.sort((a, b) => b.date.compareTo(a.date));

    if (activities.isEmpty) {
      return [
        _ActivityData(
          icon: Icons.check_circle_outline_rounded,
          title: 'Griho Account Active',
          subtitle: 'Welcome to your verified resident portal',
          date: dashboard.appUser?.createdAt ?? DateTime.now(),
        ),
      ];
    }

    return activities.take(4).toList();
  }
}

class _ActivityData {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;

  const _ActivityData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

class _ActivityItem extends StatelessWidget {
  final _ActivityData activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            activity.icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activity.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _relativeDate(activity.date),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 7. PREVIOUS RESIDENCES PREVIEW
// ============================================================================

class _TenancyHistoryPreview extends StatelessWidget {
  final List<TenancyHistory> history;
  final VoidCallback onViewItem;

  const _TenancyHistoryPreview({
    required this.history,
    required this.onViewItem,
  });

  @override
  Widget build(BuildContext context) {
    final preview = history.take(2).toList();
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final item in preview)
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onViewItem,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.propertyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Unit ${item.unitNumber} • ৳ ${_formatAmount(item.monthlyRent)} / mo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(item.endedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

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

// ============================================================================
// DASHBOARD ERROR VIEW
// ============================================================================

class _DashboardErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DashboardErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load resident portal',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS (NULL-SAFE)
// ============================================================================

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatAmount(num? amount) {
  if (amount == null) {
    return '0.00';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return _formatDate(date);
}
