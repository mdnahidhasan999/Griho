import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenancy_history.dart';
import '../providers/tenancy_history_provider.dart';

class TenantTenancyHistoryScreen extends ConsumerWidget {
  const TenantTenancyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenancy History')),
      body: _buildBody(context, ref, user),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, User? user) {
    if (user == null) {
      return const _EmptyView(
        message: 'Please sign in to view your tenancy history.',
      );
    }

    final tenantUserId = user.uid.trim();

    if (tenantUserId.isEmpty) {
      return const _EmptyView(
        message: 'Your account information is unavailable.',
      );
    }

    final historyAsync = ref.watch(myTenancyHistoryProvider(tenantUserId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorView(
        onRetry: () {
          ref.invalidate(myTenancyHistoryProvider(tenantUserId));
        },
      ),
      data: (histories) {
        if (histories.isEmpty) {
          return const _EmptyView(
            message: 'You have no previous tenancy history.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myTenancyHistoryProvider(tenantUserId));

            await ref.read(myTenancyHistoryProvider(tenantUserId).future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: histories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _HistoryCard(history: histories[index]);
            },
          ),
        );
      },
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // PROPERTY
            // ================================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    Icons.home_work_outlined,
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.propertyCode,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================================================================
            // UNIT
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Unit',
              value: history.unitName?.trim().isNotEmpty == true
                  ? history.unitName!
                  : history.unitNumber,
            ),

            const SizedBox(height: 12),

            // ================================================================
            // FLOOR
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.layers_outlined,
              label: 'Floor',
              value: history.floorNumber.toString(),
            ),

            const SizedBox(height: 12),

            // ================================================================
            // ADDRESS
            // ================================================================
            if (history.propertyAddress?.trim().isNotEmpty == true) ...[
              _HistoryInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: history.propertyAddress!,
              ),
              const SizedBox(height: 12),
            ],

            // ================================================================
            // RENT
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.payments_outlined,
              label: 'Monthly Rent',
              value: history.monthlyRent == null
                  ? 'Not provided'
                  : '৳ ${_formatRent(history.monthlyRent!)}',
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 16),

            // ================================================================
            // STARTED
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.play_arrow_outlined,
              label: 'Started',
              value: _formatDate(history.startedAt),
            ),

            const SizedBox(height: 12),

            // ================================================================
            // ENDED
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.stop_outlined,
              label: 'Ended',
              value: _formatDate(history.endedAt),
            ),

            const SizedBox(height: 12),

            // ================================================================
            // DURATION
            // ================================================================
            _HistoryInfoRow(
              icon: Icons.timelapse_outlined,
              label: 'Duration',
              value: _formatDuration(history.startedAt, history.endedAt),
            ),

            const SizedBox(height: 16),

            // ================================================================
            // STATUS
            // ================================================================
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  'Ended',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatDuration(DateTime startedAt, DateTime endedAt) {
    final difference = endedAt.difference(startedAt);

    final days = difference.inDays;

    if (days <= 0) {
      return 'Less than 1 day';
    }

    return '$days '
        '${days == 1 ? 'day' : 'days'}';
  }

  String _formatRent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
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
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 105,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
  final String message;

  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'No Tenancy History',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
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
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Unable to load tenancy history',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
