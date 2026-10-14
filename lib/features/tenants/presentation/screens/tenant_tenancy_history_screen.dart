import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenancy_history.dart';
import '../providers/tenancy_history_provider.dart';

class TenantTenancyHistoryScreen extends ConsumerWidget {
  const TenantTenancyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Tenancy History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _buildBody(context, ref, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, User? user) {
    if (user == null) {
      return const _EmptyView(
        icon: Icons.lock_outline_rounded,
        title: 'Authentication Required',
        message: 'Please sign in to view your past tenancy history and lease records.',
      );
    }

    final tenantUserId = user.uid.trim();
    if (tenantUserId.isEmpty) {
      return const _EmptyView(
        icon: Icons.account_circle_outlined,
        title: 'Account Unavailable',
        message: 'Your account information is currently unavailable. Please re-login.',
      );
    }

    final historyAsync = ref.watch(myTenancyHistoryProvider(tenantUserId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          _ErrorView(
            onRetry: () {
              ref.invalidate(myTenancyHistoryProvider(tenantUserId));
            },
          ),
      data: (histories) {
        if (histories.isEmpty) {
          return const _EmptyView(
            icon: Icons.history_toggle_off_rounded,
            title: 'No Tenancy History',
            message:
            'You do not have any past completed tenancies recorded with Griho.',
          );
        }

        final sorted = List<TenancyHistory>.from(histories)
          ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myTenancyHistoryProvider(tenantUserId));
            await ref.read(myTenancyHistoryProvider(tenantUserId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // 1. Overview Header
              _HistoryOverviewHeader(recordCount: sorted.length),

              const SizedBox(height: 18),

              Text(
                'Archived Leases (${sorted.length})',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              // 2. Chronological History Cards
              for (final history in sorted) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _HistoryCard(history: history),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// OVERVIEW HEADER
// ============================================================================

class _HistoryOverviewHeader extends StatelessWidget {
  final int recordCount;

  const _HistoryOverviewHeader({required this.recordCount});

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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.history_edu_rounded,
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
                  'Tenancy Records',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Archived lease agreements and previous residential stays.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$recordCount ${recordCount == 1 ? 'Stay' : 'Stays'}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
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
// HISTORY CARD
// ============================================================================

class _HistoryCard extends StatelessWidget {
  final TenancyHistory history;

  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final unitDisplay = history.unitName
        ?.trim()
        .isNotEmpty == true
        ? '${history.unitName!} (Unit ${history.unitNumber})'
        : 'Unit ${history.unitNumber}';

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Header & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.propertyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${history.propertyCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Ended Lease',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            // Rent Banner
            if (history.monthlyRent != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recorded Rent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '৳ ${_formatRent(history.monthlyRent!)} / mo',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Unit & Address Details
            _HistoryInfoRow(
              icon: Icons.door_front_door_outlined,
              label: 'Unit / Space',
              value: '$unitDisplay • Floor ${history.floorNumber}',
            ),

            if (history.propertyAddress
                ?.trim()
                .isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _HistoryInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: history.propertyAddress!,
              ),
            ],

            const SizedBox(height: 12),

            // Timeline & Stay Duration Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TimelineDateColumn(
                        label: 'Started',
                        date: _formatDate(history.startedAt),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      _TimelineDateColumn(
                        label: 'Ended',
                        date: _formatDate(history.endedAt),
                        isEnd: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Stay Duration: ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatDuration(history.startedAt, history.endedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  String _formatDuration(DateTime startedAt, DateTime endedAt) {
    final days = endedAt
        .difference(startedAt)
        .inDays;
    if (days <= 0) {
      return 'Less than 1 day';
    }

    final months = days ~/ 30;
    final remainingDays = days % 30;

    if (months == 0) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    }

    if (months < 12) {
      if (remainingDays == 0) {
        return '$months ${months == 1 ? 'month' : 'months'}';
      }
      return '$months ${months == 1
          ? 'mo'
          : 'mos'}, $remainingDays ${remainingDays == 1 ? 'day' : 'days'}';
    }

    final years = months ~/ 12;
    final remMonths = months % 12;

    if (remMonths == 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    }
    return '$years ${years == 1 ? 'yr' : 'yrs'}, $remMonths ${remMonths == 1
        ? 'mo'
        : 'mos'}';
  }

  String _formatRent(num value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _TimelineDateColumn extends StatelessWidget {
  final String label;
  final String date;
  final bool isEnd;

  const _TimelineDateColumn({
    required this.label,
    required this.date,
    this.isEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
      isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

// ============================================================================
// HISTORY INFO ROW
// ============================================================================

class _HistoryInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HistoryInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EMPTY VIEW
// ============================================================================

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

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
            const Text(
              'Unable to load tenancy history',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'There was an error communicating with the server. Please try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
