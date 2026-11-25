// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../billing/presentation/widgets/tenant_current_bills_card.dart';
import '../../../invitations/presentation/providers/work_invitations_providers.dart';
import '../../../more/presentation/screens/house_rules_screen.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../widgets/griho_home_chrome.dart';
import '../widgets/griho_home_components.dart';

typedef TypedQuerySnapshot = QuerySnapshot<HomeJsonMap>;

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends ConsumerState<TenantHomeScreen> {
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

  Future<void> _refresh() async {
    ref.invalidate(tenantDashboardProvider);
    await ref.read(tenantDashboardProvider.future);
  }

  void _openInvitation(TenantInvitation invitation) {
    context.push(RouteNames.tenantInvitationPath(invitation.id));
  }

  void _openInvitations() => context.push(RouteNames.tenantInvitations);

  void _openPayments() => context.push(RouteNames.tenantPayments);

  void _openTenancyHistory() => context.push(RouteNames.tenantTenancyHistory);

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
    if (propertyId.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoticesSheet(propertyId: propertyId),
    );
  }

  void _openHouseRules(TenantDashboardData d) {
    final ownerId = d.tenant?.ownerId.trim() ?? '';
    if (ownerId.isEmpty) {
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TenantHouseRulesScreen(
          ownerId: ownerId,
          propertyName: d.currentPropertyName,
        ),
      ),
    );
  }

  void _copyId(String publicId) {
    if (publicId.isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: publicId));
    GrihoFeedback.showSuccess(context, 'Griho ID copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tenantDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: const GrihoHomeAppBar(consoleLabel: 'Resident Portal'),
      body: dashboardAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading portal...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Could not load resident portal',
              subtitle: error.toString(),
              actionLabel: 'Try Again',
              onAction: _refresh,
            ),
          ),
        ),
        data: (dashboard) {
          final publicId = dashboard.appUser?.publicId ?? '';
          final active = dashboard.hasActiveTenancy;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 105),
              children: [
                GrihoHomeTopHeader(
                  name: dashboard.displayName,
                  publicId: publicId,
                ),
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
                    if (n == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const Icon(Iconsax.briefcase),
                          title: Text(
                            n == 1
                                ? '1 work invitation'
                                : '$n work invitations',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Manager / caretaker / electrician offer',
                          ),
                          trailing: const Icon(Iconsax.arrow_right_3, size: 18),
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
                    onCopyId: () => _copyId(publicId),
                  ),
                if (active) ...[
                  const SizedBox(height: 22),
                  GrihoSectionHeader(
                    'Bills & dues',
                    trailing: TextButton(
                      onPressed: _openPayments,
                      child: const Text('Payments'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const TenantCurrentBillsCard(),
                ],
                const SizedBox(height: 22),
                const GrihoSectionHeader('Quick actions'),
                const SizedBox(height: 10),
                GrihoQuickActionGrid(
                  items: [
                    if (active)
                      GrihoQuickActionItem(
                        icon: Iconsax.wallet_check,
                        title: 'Payments',
                        subtitle: 'Pay & receipts',
                        color: GrihoColors.emerald,
                        onTap: _openPayments,
                      ),
                    if (active)
                      GrihoQuickActionItem(
                        icon: Iconsax.document_text_1,
                        title: 'House rules',
                        subtitle: 'Landlord policies',
                        color: GrihoColors.deepTeal,
                        onTap: () => _openHouseRules(dashboard),
                      ),
                    if (active)
                      GrihoQuickActionItem(
                        icon: Iconsax.warning_2,
                        title: 'Report issue',
                        subtitle: 'Plumbing, electric…',
                        color: Colors.deepOrange,
                        onTap: () => _reportIssue(dashboard),
                      ),
                    if (active)
                      GrihoQuickActionItem(
                        icon: Iconsax.setting_2,
                        title: 'My requests',
                        subtitle: 'Track repairs',
                        color: Colors.indigo,
                        onTap: _openMyRequests,
                      ),
                    if (active)
                      GrihoQuickActionItem(
                        icon: Iconsax.notification_bing,
                        title: 'Notices',
                        subtitle: 'From your building',
                        color: GrihoColors.warning,
                        onTap: () => _openNotices(dashboard),
                      ),
                    GrihoQuickActionItem(
                      icon: Iconsax.sms,
                      title: 'Invitations',
                      subtitle: 'Lease offers',
                      color: Colors.blueAccent,
                      onTap: _openInvitations,
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.clock,
                      title: 'History',
                      subtitle: 'Past stays',
                      color: Colors.teal,
                      onTap: _openTenancyHistory,
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.share,
                      title: 'Share ID',
                      subtitle: 'Copy your Griho ID',
                      color: Colors.deepPurpleAccent,
                      onTap: () => _copyId(publicId),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const GrihoSectionHeader('Recent activity'),
                const SizedBox(height: 10),
                _RecentActivityCard(dashboard: dashboard),
                if (dashboard.hasTenancyHistory) ...[
                  const SizedBox(height: 22),
                  GrihoSectionHeader(
                    'Past residences',
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
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
      ),
    );
  }
}

// ============================================================================
// REPORT ISSUE -> maintenanceRequests
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

    if (tenant == null || uid == null) {
      return;
    }
    if (title.isEmpty) {
      GrihoFeedback.showError(context, 'Please describe the problem.');
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
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      GrihoFeedback.showSuccess(context, 'Request sent to your building team.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      GrihoFeedback.showError(context, 'Could not send request: $e');
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
                  icon: Icon(Iconsax.drop, size: 17),
                ),
                ButtonSegment(
                  value: 'electrical',
                  label: Text('Electric'),
                  icon: Icon(Iconsax.flash_1, size: 17),
                ),
                ButtonSegment(
                  value: 'general',
                  label: Text('Other'),
                  icon: Icon(Iconsax.setting_2, size: 17),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (v) => setState(() => _category = v.first),
            ),
            const SizedBox(height: 14),
            GrihoTextField(
              controller: _titleCtrl,
              label: 'What is the problem? *',
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: Iconsax.edit_2,
            ),
            const SizedBox(height: 12),
            GrihoTextField(
              controller: _descCtrl,
              label: 'Details (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            GrihoPrimaryButton(
              label: 'Send request',
              icon: Iconsax.send_2,
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MY REQUESTS (ONE-TIME BOUNDED READ)
// ============================================================================

class _MyRequestsSheet extends StatelessWidget {
  const _MyRequestsSheet();

  Color _color(String s) {
    switch (s) {
      case 'resolved':
        return GrihoColors.emerald;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return GrihoColors.error;
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

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: uid == null
            ? const Center(child: Text('Please sign in again.'))
            : FutureBuilder<TypedQuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('maintenanceRequests')
                    .where('tenantUserId', isEqualTo: uid)
                    .limit(40)
                    .get(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Unable to load: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const GrihoLoadingView(
                      message: 'Loading requests...',
                    );
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
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        const GrihoStatusState(
                          icon: Iconsax.setting_2,
                          title: 'No requests yet',
                          subtitle:
                              'Maintenance issues you report will appear here.',
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
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.14),
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
// BUILDING NOTICES (ONE-TIME BOUNDED READ)
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
        child: FutureBuilder<TypedQuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('buildingNotices')
              .where('propertyId', isEqualTo: propertyId)
              .limit(40)
              .get(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Unable to load: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const GrihoLoadingView(message: 'Loading notices...');
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
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const GrihoStatusState(
                    icon: Iconsax.notification_bing,
                    title: 'No notices right now',
                    subtitle: 'Announcements from your building appear here.',
                  ),
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final d = doc.data();
                      final p = (d['priority'] ?? '').toString();
                      final urgent = p == 'high' || p == 'urgent';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(
                            urgent
                                ? Iconsax.warning_2
                                : Iconsax.notification_bing,
                            color: urgent
                                ? GrihoColors.error
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
// HERO DIGITAL RESIDENCY PASS (BRAND DEEP TEAL & EMERALD)
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
          colors: [GrihoColors.deepTeal, Color(0xFF064C50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: GrihoColors.deepTeal.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GrihoColors.emerald.withValues(alpha: 0.25),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Iconsax.key,
                            size: 16,
                            color: GrihoColors.softMint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'DIGITAL RESIDENCY PASS',
                          style: TextStyle(
                            color: GrihoColors.softMint,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
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
                        color: GrihoColors.emerald.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: GrihoColors.softMint.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: GrihoColors.softMint,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Active Stay',
                            style: TextStyle(
                              color: GrihoColors.mintWhisper,
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
                      Iconsax.home_2,
                      size: 16,
                      color: GrihoColors.softMint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unitDisplayName,
                      style: const TextStyle(
                        color: GrihoColors.mintWhisper,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agreed Monthly Rent',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
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
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Moved In',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
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
// PENDING INVITATION BANNER
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
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
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
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.sms_notification,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Tenancy Invitation Received',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You are invited to finalize lease terms for "$propertyName" ($unitName) with agreed monthly rent of ৳ ${_formatAmount(invitation.rentAmount)}.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          GrihoPrimaryButton(
            label: 'Review & Accept Invitation',
            icon: Iconsax.arrow_right_3,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIGITAL TENANT PASSPORT (EMPTY RESIDENCY STATE)
// ============================================================================

class _NoActiveTenancyPassport extends StatelessWidget {
  final String userPublicId;
  final bool hasPendingInvitation;
  final VoidCallback onCopyId;

  const _NoActiveTenancyPassport({
    required this.userPublicId,
    required this.hasPendingInvitation,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPendingInvitation
                  ? Iconsax.sms_notification
                  : Iconsax.buildings_2,
              size: 38,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    onPressed: onCopyId,
                    icon: const Icon(Iconsax.copy, size: 16),
                    label: const Text('Copy ID'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// RECENT ACTIVITY TIMELINE
// ============================================================================

class _RecentActivityCard extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _RecentActivityCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = _buildActivities(dashboard);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityItem(activity: activities[index]),
            if (index != activities.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  List<_ActivityData> _buildActivities(TenantDashboardData dashboard) {
    final activities = <_ActivityData>[];
    final invitation = dashboard.pendingInvitation;
    if (invitation != null && invitation.isPending && !invitation.isExpired) {
      activities.add(
        _ActivityData(
          icon: Iconsax.sms,
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
          icon: Iconsax.key,
          title: 'Moved in to New Space',
          subtitle: dashboard.currentPropertyName ?? 'Tenancy active',
          date: tenant.tenancyStartedAt!,
        ),
      );
    }

    for (final history in dashboard.tenancyHistory.take(2)) {
      activities.add(
        _ActivityData(
          icon: Iconsax.clock,
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
          icon: Iconsax.tick_circle,
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
// PREVIOUS RESIDENCES PREVIEW
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
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
                          Iconsax.buildings_2,
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
          ),
      ],
    );
  }
}

// ============================================================================
// HELPERS
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
