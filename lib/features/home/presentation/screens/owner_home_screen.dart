// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/owner_tenants_provider.dart';
import '../widgets/griho_home_chrome.dart';
import '../widgets/griho_home_components.dart';
import '../widgets/shared_property_sheets.dart';

class OwnerHomeScreen extends ConsumerStatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  @override
  void initState() {
    super.initState();
    FcmNotificationService.instance.initialize(
      onNavigate: (route) {
        if (mounted) context.push(route);
      },
    );
  }

  void _openMaintenanceSheet(
    BuildContext context,
    String ownerId,
    String ownerName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BuildingMaintenanceSheet(
        filterField: 'ownerId',
        filterValues: [ownerId],
        actorName: ownerName,
        actorRole: 'owner',
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
      builder: (_) => BuildingNoticesSheet(
        actorUid: uid,
        actorName: userName,
        actorRole: 'owner',
        properties: properties
            .map(
              (p) => NoticePropertyOption(
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
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final properties =
        ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[];
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: GrihoHomeAppBar(
        consoleLabel: 'Owner Console',
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
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load owner account',
              subtitle: 'Please check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'Owner profile not found',
                  subtitle: 'Tap retry to reload your profile.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(currentUserProfileProvider),
                ),
              ),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 105),
              children: [
                GrihoHomeTopHeader(
                  name: profile.name,
                  publicId: profile.publicId,
                ),
                const SizedBox(height: 16),
                OpenIssuesBanner(
                  filterField: 'ownerId',
                  filterValues: [profile.uid],
                  onTap: () =>
                      _openMaintenanceSheet(context, profile.uid, profile.name),
                ),
                _OwnerSummaryCard(ownerUid: profile.uid),
                const SizedBox(height: 14),
                const _PrimaryActions(),
                const SizedBox(height: 22),
                const GrihoSectionHeader('Your team'),
                const SizedBox(height: 10),
                const _TeamCard(),
                const SizedBox(height: 22),
                const GrihoSectionHeader('Quick actions'),
                const SizedBox(height: 10),
                GrihoQuickActionGrid(
                  items: [
                    GrihoQuickActionItem(
                      icon: Iconsax.people,
                      title: 'Residents',
                      subtitle: 'Tenants & leases',
                      color: GrihoColors.emerald,
                      onTap: () => context.push(RouteNames.ownerTenants),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.buildings_2,
                      title: 'Buildings',
                      subtitle: 'Units & floors',
                      color: Colors.indigo,
                      onTap: () => context.push(RouteNames.propertyList),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.wallet_check,
                      title: 'Payments',
                      subtitle: 'Review & confirm',
                      color: Colors.green,
                      onTap: () => context.push(RouteNames.ownerPayments),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.setting_2,
                      title: 'Issues',
                      subtitle: 'Tenant complaints',
                      color: Colors.deepOrange,
                      onTap: () => _openMaintenanceSheet(
                        context,
                        profile.uid,
                        profile.name,
                      ),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.notification_bing,
                      title: 'Notices',
                      subtitle: 'Post & manage',
                      color: GrihoColors.warning,
                      onTap: () => _openNoticesSheet(
                        context,
                        profile.uid,
                        profile.name,
                        ownedProps,
                      ),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.money_change,
                      title: 'Rent control',
                      subtitle: 'Change rates',
                      color: Colors.deepPurpleAccent,
                      onTap: () => context.push(RouteNames.centralRentControl),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.receipt_item,
                      title: 'Billing rules',
                      subtitle: 'Utilities & charges',
                      color: Colors.brown,
                      onTap: () => context.push(RouteNames.ownerBillingRules),
                    ),
                    GrihoQuickActionItem(
                      icon: Iconsax.document_text,
                      title: 'Audit trail',
                      subtitle: 'Activity logs',
                      color: Colors.blueGrey,
                      onTap: () => context.push(RouteNames.activityLogs),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                GrihoSectionHeader(
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
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
      ),
    );
  }
}

/// Caches Firestore streams per ownerUid to prevent re-subscription reads on rebuilds.
class _OwnerSummaryCard extends ConsumerStatefulWidget {
  const _OwnerSummaryCard({required this.ownerUid});

  final String ownerUid;

  @override
  ConsumerState<_OwnerSummaryCard> createState() => _OwnerSummaryCardState();
}

class _OwnerSummaryCardState extends ConsumerState<_OwnerSummaryCard> {
  late Stream<QuerySnapshot> _ratesStream;
  late Stream<QuerySnapshot> _billsStream;

  @override
  void initState() {
    super.initState();
    _initStreams(widget.ownerUid);
  }

  @override
  void didUpdateWidget(covariant _OwnerSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUid != widget.ownerUid) {
      _initStreams(widget.ownerUid);
    }
  }

  void _initStreams(String uid) {
    final db = FirebaseFirestore.instance;
    _ratesStream = db
        .collection('rentRates')
        .where('ownerId', isEqualTo: uid)
        .snapshots();
    _billsStream = db
        .collection('monthlyBills')
        .where('ownerId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final properties =
        ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[];
    final owned = properties.where((p) => p.ownerId == widget.ownerUid).length;

    final tenants = ref.watch(ownerTenantsProvider).value ?? const <Tenant>[];
    final activeTenants = tenants
        .where((t) => t.status == TenantStatus.active)
        .length;

    return StreamBuilder<QuerySnapshot>(
      stream: _ratesStream,
      builder: (context, ratesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _billsStream,
          builder: (context, billsSnap) {
            final now = DateTime.now();
            final latestRateByUnit =
                <String, ({DateTime from, double amount})>{};

            for (final d
                in ratesSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final m = homeAsMap(d.data());
              final amount = m['amount'];
              final fromRaw = m['effectiveFrom'];
              final toRaw = m['effectiveTo'];
              final unitId = (m['unitId'] ?? '').toString();

              if (amount is! num || fromRaw is! Timestamp || unitId.isEmpty) {
                continue;
              }

              final from = fromRaw.toDate();
              if (from.isAfter(now)) continue;

              if (toRaw is Timestamp && !toRaw.toDate().isAfter(now)) {
                continue;
              }

              final existing = latestRateByUnit[unitId];
              if (existing == null || from.isAfter(existing.from)) {
                latestRateByUnit[unitId] = (
                  from: from,
                  amount: amount.toDouble(),
                );
              }
            }

            final rent = latestRateByUnit.values.fold<double>(
              0.0,
              (total, item) => total + item.amount,
            );

            var unsettled = 0;
            for (final d
                in billsSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final m = homeAsMap(d.data());
              final s = (m['status'] ?? 'unpaid').toString();
              if (s != 'paid' && s != 'cancelled') {
                unsettled++;
              }
            }

            final rentText = rent == rent.roundToDouble()
                ? rent.toStringAsFixed(0)
                : rent.toStringAsFixed(2);

            return GrihoHeroCard(
              eyebrow: 'EXPECTED RENT THIS MONTH',
              eyebrowIcon: Iconsax.wallet_3,
              headline: '৳ $rentText',
              metrics: [
                GrihoHeroMetric(label: 'Buildings', value: '$owned'),
                GrihoHeroMetric(label: 'Residents', value: '$activeTenants'),
                GrihoHeroMetric(
                  label: 'Unpaid bills',
                  value: '$unsettled',
                  highlight: unsettled > 0,
                ),
              ],
            );
          },
        );
      },
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
          child: GrihoPrimaryButton(
            label: 'Add resident',
            icon: Iconsax.user_add,
            onPressed: () => context.push(RouteNames.addTenant),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GrihoSecondaryButton(
            label: 'Add building',
            icon: Iconsax.building_4,
            onPressed: () async {
              await context.push(RouteNames.addProperty);
              if (!context.mounted) return;
              ref.invalidate(currentOwnerPropertiesProvider);
            },
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
                    icon: Iconsax.user_octagon,
                    label: 'Managers',
                    count: active(managers),
                    color: Colors.indigo,
                  ),
                  _TeamCount(
                    icon: Iconsax.setting_2,
                    label: 'Caretakers',
                    count: active(staff, 'caretaker'),
                    color: GrihoColors.emerald,
                  ),
                  _TeamCount(
                    icon: Iconsax.flash_1,
                    label: 'Electricians',
                    count: active(staff, 'electrician'),
                    color: GrihoColors.warning,
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
                  const Icon(Iconsax.arrow_right_3, size: 18),
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
              color: color.withValues(alpha: 0.14),
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

class _BuildingsStrip extends ConsumerWidget {
  const _BuildingsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              return const GrihoStatusState(
                icon: Iconsax.buildings_2,
                title: 'No buildings yet',
                subtitle:
                    'Add your first building to start managing units and tenants.',
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
                    Iconsax.buildings_2,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (active ? GrihoColors.emerald : GrihoColors.warning)
                              .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? GrihoColors.emerald
                            : GrihoColors.warning,
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
