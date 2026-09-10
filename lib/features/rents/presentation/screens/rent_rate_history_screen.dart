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
    final unitAsync = ref.watch(
      unitByIdProvider(unitId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent History'),
      ),
      body: unitAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(
                unitByIdProvider(unitId),
              );
            },
          );
        },
        data: (unit) {
          if (unit == null) {
            return const Center(
              child: Text('Unit not found.'),
            );
          }

          final propertyAsync = ref.watch(
            propertyByIdProvider(unit.propertyId),
          );

          return propertyAsync.when(
            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            error: (error, stackTrace) {
              return _ErrorView(
                message: error.toString(),
                onRetry: () {
                  ref.invalidate(
                    propertyByIdProvider(unit.propertyId),
                  );
                },
              );
            },
            data: (property) {
              if (property == null) {
                return const Center(
                  child: Text('Property not found.'),
                );
              }

              final historyAsync = ref.watch(
                unitRentRateHistoryProvider(
                  (
                  unitId: unit.id,
                  ownerId: property.ownerId,
                  ),
                ),
              );

              return historyAsync.when(
                loading: () {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                error: (error, stackTrace) {
                  return _ErrorView(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(
                        unitRentRateHistoryProvider(
                          (
                          unitId: unit.id,
                          ownerId: property.ownerId,
                          ),
                        ),
                      );
                    },
                  );
                },
                data: (history) {
                  return _HistoryBody(
                    unitNumber: unit.unitNumber,
                    propertyName: property.name,
                    history: history,
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

class _HistoryBody extends StatelessWidget {
  final String unitNumber;
  final String propertyName;
  final List<RentRate> history;

  const _HistoryBody({
    required this.unitNumber,
    required this.propertyName,
    required this.history,
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
              const Icon(
                Icons.history_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'No rent history',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'No rent rate has been recorded for this unit.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Provider invalidation is handled by the parent
        // when this screen is recreated.
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    unitNumber,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    propertyName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${history.length} rent '
                        '${history.length == 1 ? 'record' : 'records'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          ...List.generate(
            history.length,
                (index) {
              final rate = history[index];

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _RentRateCard(
                  rate: rate,
                  index: index,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RentRateCard extends StatelessWidget {
  final RentRate rate;
  final int index;

  const _RentRateCard({
    required this.rate,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = rate.effectiveTo == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '৳ ${_formatAmount(rate.amount)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _SourceChip(
                  source: rate.source,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _DetailRow(
              label: 'Effective From',
              value: _formatDate(
                rate.effectiveFrom,
              ),
            ),

            const SizedBox(height: 8),

            _DetailRow(
              label: 'Effective To',
              value: rate.effectiveTo == null
                  ? 'Current'
                  : _formatDate(rate.effectiveTo!),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isCurrent
                    ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Text(
                isCurrent ? 'Current' : 'Historical',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }

    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _SourceChip extends StatelessWidget {
  final RentRateSource source;

  const _SourceChip({
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final String label;

    switch (source) {
      case RentRateSource.initial:
        label = 'Initial';

      case RentRateSource.floor:
        label = 'Floor';

      case RentRateSource.unit:
        label = 'Unit';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
          ),
        ),
      ],
    );
  }
}

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
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
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