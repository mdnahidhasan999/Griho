import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

// ============================================================================
// 1. MANAGER EXECUTIVE HEADER
// ============================================================================

class ManagerExecutiveHeader extends StatelessWidget {
  final String name;
  final String publicId;

  const ManagerExecutiveHeader({
    super.key,
    required this.name,
    required this.publicId,
  });

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

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
              Row(
                children: [
                  Text(
                    _greetingText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
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
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Clipboard.setData(ClipboardData(text: publicId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Manager Griho ID copied to clipboard.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    publicId,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 2. MANAGER VAULT HERO CARD
// ============================================================================

class ManagerVaultCard extends StatelessWidget {
  final double unpaidDue;
  final int activeTenantsCount;
  final int buildingsCount;
  final int unpaidInvoicesCount;

  const ManagerVaultCard({
    super.key,
    required this.unpaidDue,
    required this.activeTenantsCount,
    required this.buildingsCount,
    required this.unpaidInvoicesCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E222D), Color(0xFF141720)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OPERATIONAL COLLECTION VAULT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontSize: 11,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'Manager Access',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Outstanding Rent & Bills to Collect',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '৳ ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unpaidDue.toStringAsFixed(0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _VaultMetricItem(
                  label: 'Assigned',
                  value: '$buildingsCount Buildings',
                ),
                _VaultMetricItem(
                  label: 'Active Leases',
                  value: '$activeTenantsCount Tenants',
                ),
                _VaultMetricItem(
                  label: 'Open Dues',
                  value: '$unpaidInvoicesCount Bills',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultMetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _VaultMetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. PULSE & SUB ACTION TILES
// ============================================================================

class ManagerPulseTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ManagerPulseTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagerSubActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const ManagerSubActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. INTERACTIVE UNITS & VACANCY EXPLORER SHEET
// ============================================================================

void showManagerUnitsSheet({
  required BuildContext context,
  required List<QueryDocumentSnapshot> unitDocs,
  required Map<String, String> propertyNames,
  String initialFilter = 'all', // 'all', 'available', 'occupied'
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ManagerUnitsSheetContent(
      unitDocs: unitDocs,
      propertyNames: propertyNames,
      initialFilter: initialFilter,
    ),
  );
}

class _ManagerUnitsSheetContent extends StatefulWidget {
  final List<QueryDocumentSnapshot> unitDocs;
  final Map<String, String> propertyNames;
  final String initialFilter;

  const _ManagerUnitsSheetContent({
    required this.unitDocs,
    required this.propertyNames,
    required this.initialFilter,
  });

  @override
  State<_ManagerUnitsSheetContent> createState() =>
      _ManagerUnitsSheetContentState();
}

class _ManagerUnitsSheetContentState extends State<_ManagerUnitsSheetContent> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredDocs = widget.unitDocs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final status = (d['status'] ?? 'available').toString();
      if (_filter == 'available') return status == 'available';
      if (_filter == 'occupied') return status != 'available';
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Units & Vacancy (${filteredDocs.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Tap any unit to inspect details, rent, or assign a tenant',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All Units')),
                  ButtonSegment(value: 'available', label: Text('Vacant')),
                  ButtonSegment(value: 'occupied', label: Text('Occupied')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: filteredDocs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No matching units found in assigned properties.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      itemBuilder: (_, i) {
                        final doc = filteredDocs[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final unitId = doc.id;
                        final unitNum = (d['unitNumber'] ?? '').toString();
                        final name = (d['name'] ?? '').toString();
                        final floor = d['floorNumber'] ?? 1;
                        final status = (d['status'] ?? 'available').toString();
                        final propId = (d['propertyId'] ?? '').toString();
                        final propName =
                            widget.propertyNames[propId] ?? 'Assigned Building';
                        final isAvailable = status == 'available';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAvailable
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant,
                              width: isAvailable ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push(
                                    RouteNames.unitDetails.replaceFirst(
                                      ':unitId',
                                      unitId,
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            (isAvailable
                                                    ? Colors.green
                                                    : Colors.indigo)
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isAvailable
                                            ? Icons.meeting_room_outlined
                                            : Icons.door_front_door_rounded,
                                        color: isAvailable
                                            ? Colors.green.shade700
                                            : Colors.indigo,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isNotEmpty
                                                ? '$name (Unit $unitNum)'
                                                : 'Unit $unitNum',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$propName • Floor $floor',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isAvailable
                                                    ? Colors.green
                                                    : Colors.blueGrey)
                                                .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isAvailable ? 'VACANT' : 'OCCUPIED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: isAvailable
                                              ? Colors.green.shade800
                                              : Colors.blueGrey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.push(
                                          RouteNames.unitDetails.replaceFirst(
                                            ':unitId',
                                            unitId,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Unit & Rent Info'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                  if (isAvailable) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          context.push(RouteNames.addTenant);
                                        },
                                        icon: const Icon(
                                          Icons.person_add_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Assign Tenant'),
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// 5. INTERACTIVE TENANTS & LEASES DIRECTORY SHEET
// ============================================================================

void showManagerTenantsSheet({
  required BuildContext context,
  required List<QueryDocumentSnapshot> tenantDocs,
  required Map<String, String> propertyNames,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ManagerTenantsSheetContent(
      tenantDocs: tenantDocs,
      propertyNames: propertyNames,
    ),
  );
}

class _ManagerTenantsSheetContent extends StatefulWidget {
  final List<QueryDocumentSnapshot> tenantDocs;
  final Map<String, String> propertyNames;

  const _ManagerTenantsSheetContent({
    required this.tenantDocs,
    required this.propertyNames,
  });

  @override
  State<_ManagerTenantsSheetContent> createState() =>
      _ManagerTenantsSheetContentState();
}

class _ManagerTenantsSheetContentState
    extends State<_ManagerTenantsSheetContent> {
  String _statusFilter = 'active'; // 'active', 'inactive', 'all'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = widget.tenantDocs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final status = (d['status'] ?? 'inactive').toString();
      if (_statusFilter == 'active') return status == 'active';
      if (_statusFilter == 'inactive') return status != 'active';
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenants Directory (${filtered.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Tap a resident to view lease, edit details, or end tenancy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active Leases')),
                  ButtonSegment(value: 'inactive', label: Text('Past / Ended')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) =>
                    setState(() => _statusFilter = s.first),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No residents found for this filter.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final tenantId = doc.id;
                        final name = (d['name'] ?? 'Resident').toString();
                        final phone = (d['phone'] ?? '').toString();
                        final status = (d['status'] ?? 'inactive').toString();
                        final propId = (d['propertyId'] ?? '').toString();
                        final propName =
                            widget.propertyNames[propId] ?? 'Assigned Building';
                        final isActive = status == 'active';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text('$propName • $phone'),
                                const SizedBox(height: 2),
                                Text(
                                  isActive
                                      ? 'Active Tenancy • Tap to Manage / End Lease'
                                      : 'Former Tenant • Tap to View / Re-activate',
                                  style: TextStyle(
                                    color: isActive ? Colors.teal : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(context);
                              context.push(
                                RouteNames.tenantDetails.replaceFirst(
                                  ':tenantId',
                                  tenantId,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.addTenant);
                  },
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Register New Resident'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
