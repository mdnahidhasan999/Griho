import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';

class RentManagementScreen
    extends ConsumerStatefulWidget {
  final String unitId;

  const RentManagementScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<RentManagementScreen> createState() =>
      _RentManagementScreenState();
}

class _RentManagementScreenState
    extends ConsumerState<RentManagementScreen> {
  Unit? _unit;
  Property? _property;
  List<Tenant> _activeTenants = [];
  RentRate? _currentRentRate;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final unit = await ref.read(
        unitByIdProvider(widget.unitId).future,
      );

      if (unit == null) {
        throw StateError('Unit not found.');
      }

      final property = await ref.read(
        propertyByIdProvider(unit.propertyId).future,
      );

      if (property == null) {
        throw StateError('Property not found.');
      }

      final getActiveTenants =
      ref.read(getActiveTenantsByUnitIdProvider);

      final tenants = await getActiveTenants(unit.id);

      final rentRate = await ref.read(
        currentRentRateProvider(
          (
          unitId: unit.id,
          ownerId: property.ownerId,
          ),
        ).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _unit = unit;
        _property = property;
        _activeTenants = tenants;
        _currentRentRate = rentRate;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      await _loadData();
      return;
    }

    ref.invalidate(
      currentRentRateProvider(
        (
        unitId: unit.id,
        ownerId: property.ownerId,
        ),
      ),
    );

    await _loadData();
  }

  void _openRentChange() {
    final unit = _unit;

    if (unit == null) {
      return;
    }

    context
        .push(
      RouteNames.changeUnitRent.replaceFirst(
        ':unitId',
        unit.id,
      ),
    )
        .then((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  void _openRentHistory() {
    final unit = _unit;

    if (unit == null) {
      return;
    }

    context.push(
      RouteNames.unitRentRateHistory.replaceFirst(
        ':unitId',
        unit.id,
      ),
    );
  }

  void _openMonthlyRent() {
    final unit = _unit;

    if (unit == null) {
      return;
    }

    context.push(
      RouteNames.unitMonthlyRent.replaceFirst(
        ':unitId',
        unit.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rent Management'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rent Management'),
        ),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rent Management'),
        ),
        body: const Center(
          child: Text(
            'Required information was not found.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Management'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _UnitHeader(
              unit: unit,
              property: property,
            ),
            const SizedBox(height: 20),
            _CurrentTenantCard(
              tenants: _activeTenants,
            ),
            const SizedBox(height: 16),
            _CurrentRentCard(
              rentRate: _currentRentRate,
              hasActiveTenant: _activeTenants.isNotEmpty,
              onChangeRent: _openRentChange,
            ),
            const SizedBox(height: 16),
            if (_currentRentRate != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openMonthlyRent,
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                  ),
                  label: const Text(
                    'Monthly Rent',
                  ),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openRentHistory,
                icon: const Icon(Icons.history),
                label: const Text(
                  'View Rent History',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitHeader extends StatelessWidget {
  final Unit unit;
  final Property property;

  const _UnitHeader({
    required this.unit,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 52,
            ),
            const SizedBox(height: 24),
            Text(
              unit.unitNumber,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              unit.name?.trim().isNotEmpty == true
                  ? unit.name!
                  : 'Unit',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              property.name,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Floor ${unit.floorNumber}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentTenantCard extends StatelessWidget {
  final List<Tenant> tenants;

  const _CurrentTenantCard({
    required this.tenants,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Current Tenant',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 16),
            if (tenants.isEmpty)
              const Text(
                'No active tenant is assigned to this unit.',
              )
            else
              ...List.generate(
                tenants.length,
                    (index) {
                  final tenant = tenants[index];

                  return Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      if (index > 0)
                        const Divider(
                          height: 24,
                        ),
                      Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              _initials(
                                tenant.name,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenant.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (tenant.phone
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    tenant.phone,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentRentCard extends StatelessWidget {
  final RentRate? rentRate;
  final bool hasActiveTenant;
  final VoidCallback onChangeRent;

  const _CurrentRentCard({
    required this.rentRate,
    required this.hasActiveTenant,
    required this.onChangeRent,
  });

  @override
  Widget build(BuildContext context) {
    if (rentRate == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Current Rent',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                hasActiveTenant
                    ? 'No rent rate has been configured for this unit.'
                    : 'No active tenant is assigned. The initial rent will be set when a tenant invitation is accepted.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

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
                    'Current Rent',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                ),
                _SourceChip(
                  source: rentRate!.source,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '৳ ${_formatAmount(rentRate!.amount)}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Effective from '
                  '${_formatDate(rentRate!.effectiveFrom)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasActiveTenant
                    ? onChangeRent
                    : null,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Change Rent',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final RentRateSource source;

  const _SourceChip({
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        _sourceLabel(source),
      ),
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

String _initials(String name) {
  final value = name.trim();

  if (value.isEmpty) {
    return '?';
  }

  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length == 1) {
    return parts.first
        .substring(
      0,
      parts.first.length >= 2
          ? 2
          : 1,
    )
        .toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'
      .toUpperCase();
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}

String _formatDate(DateTime dateTime) {
  final date = dateTime.toLocal();

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _sourceLabel(RentRateSource source) {
  switch (source) {
    case RentRateSource.initial:
      return 'Initial';

    case RentRateSource.property:
      return 'Property';

    case RentRateSource.floor:
      return 'Floor';

    case RentRateSource.unit:
      return 'Unit';
  }
}