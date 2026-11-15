// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

class ActivityAuditLogScreen extends ConsumerStatefulWidget {
  const ActivityAuditLogScreen({super.key});

  @override
  ConsumerState<ActivityAuditLogScreen> createState() =>
      _ActivityAuditLogScreenState();
}

class _ActivityAuditLogScreenState
    extends ConsumerState<ActivityAuditLogScreen> {
  String _selectedFilter =
      'all'; // 'all', 'manager', 'staff', 'maintenance', 'rent', 'billing', 'tenant'

  Widget _buildLogsBody(
    BuildContext context,
    ThemeData theme,
    Stream<QuerySnapshot> logsStream,
  ) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                label: 'Staff (Caretaker/Elec)',
                selected: _selectedFilter == 'staff',
                onTap: () => setState(() => _selectedFilter = 'staff'),
              ),
              const SizedBox(width: 8),
              _FilterChipItem(
                label: 'Maintenance',
                selected: _selectedFilter == 'maintenance',
                onTap: () => setState(() => _selectedFilter = 'maintenance'),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: logsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load audit logs: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final rawDocs =
                  snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
              final sortedDocs = [...rawDocs]
                ..sort((a, b) {
                  final aData = _asMap(a.data());
                  final bData = _asMap(b.data());
                  final aTime =
                      (aData['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      (bData['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              final filteredDocs = sortedDocs.where((doc) {
                final d = _asMap(doc.data());
                final role = (d['actorRole'] ?? '').toString().toLowerCase();
                final cat = (d['category'] ?? '').toString().toLowerCase();

                if (_selectedFilter == 'manager') {
                  return role == 'manager';
                }
                if (_selectedFilter == 'staff') {
                  return role == 'caretaker' || role == 'electrician';
                }
                if (_selectedFilter == 'maintenance') {
                  return cat == 'maintenance';
                }
                if (_selectedFilter == 'rent') {
                  return cat == 'rent';
                }
                if (_selectedFilter == 'billing') {
                  return cat == 'billing' || cat == 'payment';
                }
                if (_selectedFilter == 'tenant') {
                  return cat == 'tenant';
                }
                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 52,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Activity Recorded Yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rent adjustments, bill generations, maintenance updates, and team actions will appear here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = _asMap(filteredDocs[index].data());
                  return _AuditLogCard(data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Activity & Audit Trail',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          // Owner সরাসরি নিজের ownerId দিয়ে লগ দেখবেন
          if (profile.defaultDashboard == 'owner') {
            final ownerLogsStream = firestore
                .collection('activityLogs')
                .where('ownerId', isEqualTo: profile.uid)
                .limit(100)
                .snapshots();
            return _buildLogsBody(context, theme, ownerLogsStream);
          }

          // Manager তার active managerAccess বিল্ডিংগুলোর লগ দেখবেন
          return StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('managerAccess')
                .where('userId', isEqualTo: profile.uid)
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, accessSnap) {
              if (accessSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final propIds =
                  (accessSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
                      .map(
                        (d) => (_asMap(d.data())['propertyId'] ?? '')
                            .toString()
                            .trim(),
                      )
                      .where((id) => id.isNotEmpty)
                      .toSet()
                      .take(10)
                      .toList();

              final managerLogsStream = propIds.isEmpty
                  ? const Stream<QuerySnapshot>.empty()
                  : firestore
                        .collection('activityLogs')
                        .where('propertyId', whereIn: propIds)
                        .limit(100)
                        .snapshots();

              return _buildLogsBody(context, theme, managerLogsStream);
            },
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final Map<String, dynamic> data;

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
      'caretaker' => ('CARETAKER', Colors.teal.shade700),
      'electrician' => ('ELECTRICIAN', Colors.amber.shade900),
      _ => ('OWNER', Colors.indigo),
    };

    final (icon, iconColor) = switch (category) {
      'rent' => (Icons.price_change_rounded, Colors.indigo),
      'billing' => (Icons.receipt_long_rounded, Colors.amber.shade900),
      'payment' => (Icons.payments_rounded, Colors.green.shade700),
      'tenant' => (Icons.person_add_alt_1_rounded, Colors.teal),
      'maintenance' => (Icons.build_circle_rounded, Colors.deepOrange),
      _ => (Icons.shield_outlined, theme.colorScheme.primary),
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
                  color: iconColor.withValues(alpha: 0.12),
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
                  color: roleColor.withValues(alpha: 0.12),
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
