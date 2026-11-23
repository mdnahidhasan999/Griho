// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/griho_home_components.dart';

class ActivityAuditLogScreen extends ConsumerStatefulWidget {
  const ActivityAuditLogScreen({super.key});

  @override
  ConsumerState<ActivityAuditLogScreen> createState() =>
      _ActivityAuditLogScreenState();
}

class _ActivityAuditLogScreenState
    extends ConsumerState<ActivityAuditLogScreen> {
  String _selectedFilter = 'all';
  Future<HomeDocList>? _logsFuture;
  String? _cachedKey;

  Future<HomeDocList> _getOrLoadLogs(String uid, String? dashboard) {
    final key = '${uid}_${dashboard ?? ''}';
    if (_logsFuture == null || _cachedKey != key) {
      _cachedKey = key;
      _logsFuture = _fetchLogs(uid: uid, isOwner: dashboard == 'owner');
    }
    return _logsFuture!;
  }

  Future<void> _refreshLogs(String uid, String? dashboard) async {
    final future = _fetchLogs(uid: uid, isOwner: dashboard == 'owner');
    setState(() {
      _cachedKey = '${uid}_${dashboard ?? ''}';
      _logsFuture = future;
    });
    await future;
  }

  /// One-time fetch with limit(60) instead of live snapshots to save Firestore reads.
  Future<HomeDocList> _fetchLogs({
    required String uid,
    required bool isOwner,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (isOwner) {
      final snap = await firestore
          .collection('activityLogs')
          .where('ownerId', isEqualTo: uid)
          .limit(60)
          .get();
      return _sortByDateDesc(snap.docs);
    }

    final accessSnap = await firestore
        .collection('managerAccess')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(10)
        .get();

    final propIds = accessSnap.docs
        .map((d) => (homeAsMap(d.data())['propertyId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(10)
        .toList();

    if (propIds.isEmpty) {
      return const <QueryDocumentSnapshot>[];
    }

    final snap = await firestore
        .collection('activityLogs')
        .where('propertyId', whereIn: propIds)
        .limit(60)
        .get();
    return _sortByDateDesc(snap.docs);
  }

  HomeDocList _sortByDateDesc(HomeDocList docs) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aTime =
          (homeAsMap(a.data())['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          (homeAsMap(b.data())['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  bool _matchesFilter(HomeJsonMap d) {
    final role = (d['actorRole'] ?? '').toString().toLowerCase();
    final cat = (d['category'] ?? '').toString().toLowerCase();

    switch (_selectedFilter) {
      case 'manager':
        return role == 'manager';
      case 'staff':
        return role == 'caretaker' || role == 'electrician';
      case 'maintenance':
        return cat == 'maintenance';
      case 'rent':
        return cat == 'rent';
      case 'billing':
        return cat == 'billing' || cat == 'payment';
      case 'tenant':
        return cat == 'tenant';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Activity & Audit Trail')),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading audit logs...'),
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
                  subtitle: 'Please sign in again to view activity logs.',
                ),
              ),
            );
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _FilterChipItem(
                      label: 'All Activity',
                      selected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Managers',
                      selected: _selectedFilter == 'manager',
                      onTap: () => setState(() => _selectedFilter = 'manager'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Staff',
                      selected: _selectedFilter == 'staff',
                      onTap: () => setState(() => _selectedFilter = 'staff'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Maintenance',
                      selected: _selectedFilter == 'maintenance',
                      onTap: () =>
                          setState(() => _selectedFilter = 'maintenance'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Rent Changes',
                      selected: _selectedFilter == 'rent',
                      onTap: () => setState(() => _selectedFilter = 'rent'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Bills & Payments',
                      selected: _selectedFilter == 'billing',
                      onTap: () => setState(() => _selectedFilter = 'billing'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Tenants',
                      selected: _selectedFilter == 'tenant',
                      onTap: () => setState(() => _selectedFilter = 'tenant'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<HomeDocList>(
                  future: _getOrLoadLogs(profile.uid, profile.defaultDashboard),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const GrihoLoadingView(
                        message: 'Loading activity trail...',
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GrihoStatusState(
                            icon: Iconsax.warning_2,
                            title: 'Unable to load audit logs',
                            subtitle: '${snapshot.error}',
                            actionLabel: 'Retry',
                            onAction: () => _refreshLogs(
                              profile.uid,
                              profile.defaultDashboard,
                            ),
                          ),
                        ),
                      );
                    }

                    final allDocs =
                        snapshot.data ?? const <QueryDocumentSnapshot>[];
                    final filteredDocs = allDocs
                        .where((doc) => _matchesFilter(homeAsMap(doc.data())))
                        .toList();

                    if (filteredDocs.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () =>
                            _refreshLogs(profile.uid, profile.defaultDashboard),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 40),
                            GrihoStatusState(
                              icon: Iconsax.document_text,
                              title: 'No Activity Recorded Yet',
                              subtitle:
                                  'Rent adjustments, bill generations, maintenance updates, and team actions will appear here.',
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () =>
                          _refreshLogs(profile.uid, profile.defaultDashboard),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          return _AuditLogCard(
                            data: homeAsMap(filteredDocs[index].data()),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final HomeJsonMap data;

  const _AuditLogCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['actionTitle'] ?? 'Action').toString();
    final details = (data['details'] ?? '').toString();
    final propertyName = (data['propertyName'] ?? 'Building').toString();
    final actorName = (data['actorName'] ?? 'User').toString();
    final actorRole = (data['actorRole'] ?? 'owner').toString().toLowerCase();
    final category = (data['category'] ?? 'general').toString().toLowerCase();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final (roleLabel, roleColor) = switch (actorRole) {
      'manager' => ('MANAGER', Colors.deepPurple),
      'caretaker' => ('CARETAKER', GrihoColors.emerald),
      'electrician' => ('ELECTRICIAN', GrihoColors.warning),
      _ => ('OWNER', theme.colorScheme.primary),
    };

    final (icon, iconColor) = switch (category) {
      'rent' => (Iconsax.money_change, Colors.indigo),
      'billing' => (Iconsax.receipt_item, GrihoColors.warning),
      'payment' => (Iconsax.wallet_check, GrihoColors.emerald),
      'tenant' => (Iconsax.user_add, Colors.teal),
      'maintenance' => (Iconsax.setting_2, Colors.deepOrange),
      _ => (Iconsax.shield_tick, theme.colorScheme.primary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      propertyName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: roleColor,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              details,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By: $actorName',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                createdAt != null ? _formatDateTime(createdAt) : 'Just now',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} • $h:$min';
  }
}
