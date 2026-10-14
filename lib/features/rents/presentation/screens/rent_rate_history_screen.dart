import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';

class RentRateHistoryScreen extends ConsumerWidget {
  final String unitId;

  const RentRateHistoryScreen({
    super.key,
    required this.unitId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unitAsync = ref.watch(unitByIdProvider(unitId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Rent Rate History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: unitAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(unitByIdProvider(unitId));
          },
        ),
        data: (unit) {
          if (unit == null) {
            return const Center(child: Text('Unit information not found.'));
          }

          final propertyAsync = ref.watch(propertyByIdProvider(unit.propertyId));

          return propertyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _ErrorView(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(propertyByIdProvider(unit.propertyId));
              },
            ),
            data: (property) {
              if (property == null) {
                return const Center(child: Text('Property information not found.'));
              }

              final historyProvider = unitRentRateHistoryProvider(
                (
                unitId: unit.id,
                ownerId: property.ownerId,
                ),
              );

              final historyAsync = ref.watch(historyProvider);

              return historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _ErrorView(
                  message: error.toString(),
                  onRetry: () {
                    ref.invalidate(historyProvider);
                  },
                ),
                data: (history) {
                  return _HistoryBody(
                    unitNumber: unit.unitNumber,
                    floorNumber: unit.floorNumber,
                    propertyName: property.name,
                    history: history,
                    onRefresh: () async {
                      ref.invalidate(historyProvider);
                      await ref.read(historyProvider.future);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// HISTORY BODY
// ============================================================================

class _HistoryBody extends StatelessWidget {
  final String unitNumber;
  final int floorNumber;
  final String propertyName;
  final List<RentRate> history;
  final Future<void> Function() onRefresh;

  const _HistoryBody({
    required this.unitNumber,
    required this.floorNumber,
    required this.propertyName,
    required this.history,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Rent History Recorded',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'There are no historical rent rate snapshots for Unit $unitNumber yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 1. Overview Unit Header Card
          _UnitOverviewCard(
            unitNumber: unitNumber,
            floorNumber: floorNumber,
            propertyName: propertyName,
            recordCount: history.length,
          ),

          const SizedBox(height: 20),

          Text(
            'Timeline & Rate Revisions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // 2. Chronological History Cards
          for (var i = 0; i < history.length; i++) ...[
            _RentRateCard(
              rate: history[i],
              isFirst: i == 0,
            ),
            if (i != history.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// UNIT OVERVIEW CARD
// ============================================================================

class _UnitOverviewCard extends StatelessWidget {
  final String unitNumber;
  final int floorNumber;
  final String propertyName;
  final int recordCount;

  const _UnitOverviewCard({
    required this.unitNumber,
    required this.floorNumber,
    required this.propertyName,
    required this.recordCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.domain_rounded,
              size: 26,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit $unitNumber',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$propertyName • Floor $floorNumber',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$recordCount ${recordCount == 1 ? 'Record' : 'Records'}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RENT RATE ITEM CARD
// ============================================================================

class _RentRateCard extends StatelessWidget {
  final RentRate rate;
  final bool isFirst;

  const _RentRateCard({
    required this.rate,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = rate.effectiveTo == null;

    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '৳ ${_formatAmount(rate.amount)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCurrent ? 'Current Active' : 'Historical',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Effective Range',
            value: '${_formatDate(rate.effectiveFrom)} → ${rate.effectiveTo == null ? 'Ongoing' : _formatDate(rate.effectiveTo!)}',
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.layers_outlined,
            label: 'Adjustment Scope',
            value: _sourceLabel(rate.source),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

String _formatAmount(num? amount) {
  if (amount == null) {
    return '0.00';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _sourceLabel(RentRateSource source) {
  switch (source) {
    case RentRateSource.initial:
      return 'Initial Tenancy Agreement';
    case RentRateSource.property:
      return 'Property-Wide Adjustment';
    case RentRateSource.floor:
      return 'Floor-Level Adjustment';
    case RentRateSource.unit:
      return 'Unit-Specific Adjustment';
  }
}
