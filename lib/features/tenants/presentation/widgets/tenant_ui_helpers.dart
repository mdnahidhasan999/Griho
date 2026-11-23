// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';

String tenantInitials(String name) {
  final value = name.trim();
  if (value.isEmpty) {
    return 'T';
  }
  final parts = value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String formatTenantAmount(num? amount) {
  if (amount == null) {
    return '0';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String formatTenantDate(DateTime dateTime, {bool includeTime = false}) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  if (!includeTime) {
    return '$day/$month/${local.year}';
  }
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} at $hour:$minute';
}

String formatUnitDisplay(Unit? unit, {bool includeFloor = true}) {
  if (unit == null) {
    return 'Unit not found';
  }
  final name = unit.name?.trim();
  if (name != null && name.isNotEmpty) {
    return includeFloor
        ? '$name • Floor ${unit.floorNumber}'
        : '$name (Unit ${unit.unitNumber})';
  }
  return includeFloor
      ? 'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}'
      : 'Unit ${unit.unitNumber}';
}

String formatInvitationUnit(TenantInvitation invitation) {
  final unitName = invitation.unitName?.trim();
  final unitNumber = invitation.unitNumber?.trim();

  if (unitName != null &&
      unitName.isNotEmpty &&
      unitNumber != null &&
      unitNumber.isNotEmpty) {
    return '$unitName (Unit $unitNumber)';
  }
  if (unitName != null && unitName.isNotEmpty) {
    return unitName;
  }
  if (unitNumber != null && unitNumber.isNotEmpty) {
    return 'Unit $unitNumber';
  }
  return 'Unit unassigned';
}

class TenantStatusChip extends StatelessWidget {
  const TenantStatusChip({super.key, required this.status});

  final TenantStatus status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == TenantStatus.active;
    final color = isActive ? GrihoColors.emerald : GrihoColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class TenantMetricBadge extends StatelessWidget {
  const TenantMetricBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
    this.filled = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? highlightColor;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: filled
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: filled
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 17,
            color: highlightColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TenantSectionHeader extends StatelessWidget {
  const TenantSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class TenantListCard extends ConsumerWidget {
  const TenantListCard({
    super.key,
    required this.tenant,
    required this.onTap,
    this.showPropertyBadge = false,
  });

  final Tenant tenant;
  final VoidCallback onTap;
  final bool showPropertyBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unitAsync = ref.watch(unitByIdProvider(tenant.unitId));
    final propertyAsync = showPropertyBadge
        ? ref.watch(propertyByIdProvider(tenant.propertyId))
        : null;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  tenantInitials(tenant.name),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tenant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TenantStatusChip(status: tenant.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.call,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tenant.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (tenant.email != null &&
                        tenant.email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Iconsax.sms,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tenant.email!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (propertyAsync != null)
                          propertyAsync.when(
                            loading: () => const _MetaBadgeLoading(
                              icon: Iconsax.buildings_2,
                            ),
                            error: (_, _) => const _MetaBadge(
                              icon: Iconsax.buildings_2,
                              text: 'Property unavailable',
                            ),
                            data: (Property? property) => _MetaBadge(
                              icon: Iconsax.buildings_2,
                              text: property?.name ?? 'Unknown Building',
                            ),
                          ),
                        unitAsync.when(
                          loading: () =>
                              const _MetaBadgeLoading(icon: Iconsax.home_2),
                          error: (_, _) => const _MetaBadge(
                            icon: Iconsax.home_2,
                            text: 'Unit unavailable',
                          ),
                          data: (Unit? unit) => _MetaBadge(
                            icon: Iconsax.home_2,
                            text: formatUnitDisplay(
                              unit,
                              includeFloor: !showPropertyBadge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Iconsax.arrow_right_3,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadgeLoading extends StatelessWidget {
  const _MetaBadgeLoading({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          const SizedBox(
            height: 10,
            width: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ],
      ),
    );
  }
}
