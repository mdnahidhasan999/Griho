import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';

import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../tenants/presentation/providers/tenancy_history_provider.dart';

import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';

import '../../domain/entities/monthly_rent.dart';
import '../../domain/entities/generate_monthly_rent_request.dart';
import '../providers/monthly_rent_provider.dart';

class MonthlyRentScreen extends ConsumerStatefulWidget {
  final String unitId;

  const MonthlyRentScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<MonthlyRentScreen> createState() =>
      _MonthlyRentScreenState();
}

class _MonthlyRentScreenState extends ConsumerState<MonthlyRentScreen> {
  Unit? _unit;
  Property? _property;

  List<Tenant> _activeTenants = const [];

  List<TenancyHistory> _tenancyHistory = const [];
  List<MonthlyRent> _monthlyRents = const [];

  bool _isLoading = true;
  bool _isGenerating = false;

  String? _errorMessage;

  DateTime _billingPeriodStart = _firstDayOfMonth(
    DateTime.now(),
  );

  DateTime _billingPeriodEnd = _firstDayOfNextMonth(
    DateTime.now(),
  );

  DateTime _dueDate = _defaultDueDate(
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ==========================================================================
  // LOAD DATA
  // ==========================================================================

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

      final activeTenants = await getActiveTenants(
        unit.id,
      );

      final tenancyHistory = await ref.read(
        unitHistoryProvider(
          (
          unitId: unit.id,
          ownerId: property.ownerId,
          ),
        ).future,
      );

      final monthlyRents = await ref.read(
        monthlyRentByUnitAndPeriodProvider(
          (
          unitId: unit.id,
          ownerId: property.ownerId,
          billingPeriodStart: _billingPeriodStart,
          ),
        ).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _unit = unit;
        _property = property;

        _activeTenants = activeTenants;

        _tenancyHistory = tenancyHistory;
        _monthlyRents = monthlyRents;

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

  // ==========================================================================
  // BILLING MONTH
  // ==========================================================================

  Future<void> _selectBillingMonth() async {
    if (_isGenerating) {
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: _billingPeriodStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select billing month',
    );

    if (!mounted || selected == null) {
      return;
    }

    final start = _firstDayOfMonth(selected);
    final end = _firstDayOfNextMonth(selected);

    var dueDate = _dueDate;

    final desiredDay = dueDate.day;

    final lastDayOfMonth = end.subtract(
      const Duration(days: 1),
    );

    final safeDay = desiredDay > lastDayOfMonth.day
        ? lastDayOfMonth.day
        : desiredDay;

    dueDate = DateTime(
      start.year,
      start.month,
      safeDay,
    );

    setState(() {
      _billingPeriodStart = start;
      _billingPeriodEnd = end;
      _dueDate = dueDate;
    });

    await _loadBillingPeriodData();
  }

  Future<void> _loadBillingPeriodData() async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return;
    }

    try {
      final monthlyRents = await ref.read(
        monthlyRentByUnitAndPeriodProvider(
          (
          unitId: unit.id,
          ownerId: property.ownerId,
          billingPeriodStart: _billingPeriodStart,
          ),
        ).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _monthlyRents = monthlyRents;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to load monthly rent: $error',
      );
    }
  }

  // ==========================================================================
  // DUE DATE
  // ==========================================================================

  Future<void> _selectDueDate() async {
    final lastDay = _billingPeriodEnd.subtract(
      const Duration(days: 1),
    );

    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_billingPeriodStart)
          ? _billingPeriodStart
          : _dueDate,
      firstDate: _billingPeriodStart,
      lastDate: lastDay,
      helpText: 'Select due date',
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  // ==========================================================================
  // GENERATE MONTHLY RENT
  // ==========================================================================

  Future<void> _generateMonthlyRent() async {
    if (_isGenerating) {
      return;
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      _showError(
        'Unit or property information is unavailable.',
      );
      return;
    }

    if (_dueDate.isBefore(_billingPeriodStart)) {
      _showError(
        'Due date cannot be before the billing period starts.',
      );
      return;
    }

    final tenancySegments = _resolveBillingTenancySegments();

    if (tenancySegments.isEmpty) {
      _showError(
        'No tenant tenancy period overlaps this billing month.',
      );
      return;
    }

    if (_monthlyRents.isNotEmpty) {
      _showError(
        'Monthly rent has already been generated for this billing period.',
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final generateMonthlyRent =
      ref.read(generateMonthlyRentProvider);

      final generatedRents = <MonthlyRent>[];

      for (final segment in tenancySegments) {
        final request = GenerateMonthlyRentRequest(
          ownerId: property.ownerId,
          propertyId: property.id,
          unitId: unit.id,
          tenantId: segment.tenantId,
          tenantUserId: segment.tenantUserId,
          billingPeriodStart: _billingPeriodStart,
          billingPeriodEnd: _billingPeriodEnd,
          dueDate: _dueDate,
          tenancyStart: segment.startedAt,
          tenancyEnd: segment.endedAt,
        );

        final rents = await generateMonthlyRent(
          request,
        );

        generatedRents.addAll(rents);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
      });

      await _loadBillingPeriodData();

      if (!mounted) {
        return;
      }

      ref.invalidate(
        unitMonthlyRentHistoryProvider(
          (
          unitId: unit.id,
          ownerId: property.ownerId,
          ),
        ),
      );

      if (generatedRents.isEmpty) {
        _showError(
          'No rent was generated for the selected billing period.',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${generatedRents.length} monthly rent '
                '${generatedRents.length == 1 ? 'record' : 'records'} '
                'generated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
      });

      _showError(
        'Unable to generate monthly rent: $error',
      );
    }
  }

  // ==========================================================================
  // TENANCY SEGMENT RESOLUTION
  // ==========================================================================

  List<_BillingTenancySegment> _resolveBillingTenancySegments() {
    final segments = <_BillingTenancySegment>[];

    final billingStart = _billingPeriodStart;
    final billingEnd = _billingPeriodEnd.subtract(
      const Duration(days: 1),
    );

    // ------------------------------------------------------------------------
    // Historical tenancies
    // ------------------------------------------------------------------------

    for (final history in _tenancyHistory) {
      final overlapStart = _maxDate(
        billingStart,
        _dateOnly(history.startedAt),
      );

      final overlapEnd = _minDate(
        billingEnd,
        _dateOnly(history.endedAt),
      );

      if (overlapEnd.isBefore(overlapStart)) {
        continue;
      }

      segments.add(
        _BillingTenancySegment(
          tenantId: history.tenantId,
          tenantUserId: history.tenantUserId,
          startedAt: overlapStart,
          endedAt: overlapEnd,
          sourceKey:
          'history_${history.id}_${_dateKey(overlapStart)}_'
              '${_dateKey(overlapEnd)}',
        ),
      );
    }

    // ------------------------------------------------------------------------
    // Current active tenancy
    // ------------------------------------------------------------------------

    for (final tenant in _activeTenants) {
      final tenancyStart = tenant.tenancyStartedAt;

      if (tenancyStart == null) {
        continue;
      }

      final overlapStart = _maxDate(
        billingStart,
        _dateOnly(tenancyStart),
      );

      final overlapEnd = billingEnd;

      if (overlapEnd.isBefore(overlapStart)) {
        continue;
      }

      segments.add(
        _BillingTenancySegment(
          tenantId: tenant.id,
          tenantUserId: tenant.userId,
          startedAt: overlapStart,
          endedAt: null,
          sourceKey:
          'active_${tenant.id}_${_dateKey(overlapStart)}',
        ),
      );
    }

    // ------------------------------------------------------------------------
    // Remove duplicate segments.
    // ------------------------------------------------------------------------

    final unique = <String, _BillingTenancySegment>{};

    for (final segment in segments) {
      unique[segment.sourceKey] = segment;
    }

    final result = unique.values.toList();

    result.sort(
          (a, b) =>
          a.startedAt.compareTo(
            b.startedAt,
          ),
    );

    return result;
  }

  // ==========================================================================
  // UI
  // ==========================================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Monthly Rent'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Monthly Rent'),
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
          title: const Text('Monthly Rent'),
        ),
        body: const Center(
          child: Text(
            'Required information not found.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Rent'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _UnitHeader(
              unit: unit,
              property: property,
            ),

            const SizedBox(height: 20),

            _BillingPeriodCard(
              billingPeriodStart: _billingPeriodStart,
              billingPeriodEnd: _billingPeriodEnd,
              onTap: _isGenerating
                  ? null
                  : _selectBillingMonth,
            ),

            const SizedBox(height: 16),

            _MonthlyRentSummaryCard(
              monthlyRents: _monthlyRents,
            ),

            const SizedBox(height: 16),

            if (_monthlyRents.isNotEmpty)
              _GeneratedMonthlyRentsCard(
                monthlyRents: _monthlyRents,
              )
            else
              _GenerateMonthlyRentCard(
                tenants: _resolveDisplayTenants(),
                dueDate: _dueDate,
                isGenerating: _isGenerating,
                onSelectDueDate: _selectDueDate,
                onGenerate: _generateMonthlyRent,
              ),

            const SizedBox(height: 20),

            _MonthlyRentHistorySection(
              unitId: unit.id,
              ownerId: property.ownerId,
            ),
          ],
        ),
      ),
    );
  }

  List<Tenant> _resolveDisplayTenants() {
    if (_activeTenants.isNotEmpty) {
      return _activeTenants;
    }

    return const [];
  }
}

// ============================================================================
// BILLING TENANCY SEGMENT
// ============================================================================

class _BillingTenancySegment {
  final String tenantId;
  final String? tenantUserId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String sourceKey;

  const _BillingTenancySegment({
    required this.tenantId,
    required this.tenantUserId,
    required this.startedAt,
    required this.endedAt,
    required this.sourceKey,
  });
}

// ============================================================================
// UNIT HEADER
// ============================================================================

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              unit.unitNumber,
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              property.name,
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Floor ${unit.floorNumber}',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BILLING PERIOD
// ============================================================================

class _BillingPeriodCard extends StatelessWidget {
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final VoidCallback? onTap;

  const _BillingPeriodCard({
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final periodEnd = billingPeriodEnd.subtract(
      const Duration(days: 1),
    );

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.calendar_month_outlined,
        ),
        title: const Text(
          'Billing Period',
        ),
        subtitle: Text(
          '${_formatMonth(billingPeriodStart)}\n'
              '${_formatDate(billingPeriodStart)} - '
              '${_formatDate(periodEnd)}',
        ),
        isThreeLine: true,
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================================
// SUMMARY
// ============================================================================

class _MonthlyRentSummaryCard extends StatelessWidget {
  final List<MonthlyRent> monthlyRents;

  const _MonthlyRentSummaryCard({
    required this.monthlyRents,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyRents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No monthly rent has been generated '
                      'for this billing period.',
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = monthlyRents.fold<double>(
      0,
          (sum, rent) => sum + rent.amount,
    );

    final chargeableDays = monthlyRents.fold<int>(
      0,
          (sum, rent) => sum + rent.chargeableDays,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Billing Summary',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Rent Records',
              value: '${monthlyRents.length}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Chargeable Days',
              value: '$chargeableDays',
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Total Rent',
              value: '৳ ${_formatAmount(total)}',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GENERATED RENT RECORDS
// ============================================================================

class _GeneratedMonthlyRentsCard extends StatelessWidget {
  final List<MonthlyRent> monthlyRents;

  const _GeneratedMonthlyRentsCard({
    required this.monthlyRents,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...monthlyRents]
      ..sort(
            (a, b) =>
            a.chargePeriodStart.compareTo(
              b.chargePeriodStart,
            ),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated Rent',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            ...List.generate(
              sorted.length,
                  (index) {
                final rent = sorted[index];

                return Column(
                  children: [
                    if (index > 0)
                      const Divider(
                        height: 28,
                      ),
                    _GeneratedRentItem(
                      monthlyRent: rent,
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

class _GeneratedRentItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _GeneratedRentItem({
    required this.monthlyRent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rent Segment',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleSmall,
              ),
            ),
            _StatusChip(
              status: monthlyRent.status,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '৳ ${_formatAmount(monthlyRent.amount)}',
          style: Theme
              .of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _InfoRow(
          label: 'Monthly Rate',
          value: '৳ ${_formatAmount(monthlyRent.monthlyRate)}',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          label: 'Charge Period',
          value:
          '${_formatDate(monthlyRent.chargePeriodStart)} - '
              '${_formatDate(monthlyRent.chargePeriodEnd)}',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          label: 'Chargeable Days',
          value:
          '${monthlyRent.chargeableDays} / '
              '${monthlyRent.daysInBillingPeriod}',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          label: 'Due Date',
          value: _formatDate(monthlyRent.dueDate),
        ),
      ],
    );
  }
}

// ============================================================================
// GENERATE CARD
// ============================================================================

class _GenerateMonthlyRentCard extends StatelessWidget {
  final List<Tenant> tenants;
  final DateTime dueDate;
  final bool isGenerating;
  final VoidCallback onSelectDueDate;
  final VoidCallback onGenerate;

  const _GenerateMonthlyRentCard({
    required this.tenants,
    required this.dueDate,
    required this.isGenerating,
    required this.onSelectDueDate,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final hasTenant = tenants.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Monthly Rent',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),

            if (!hasTenant)
              const _InfoRow(
                label: 'Tenant',
                value: 'No active tenant.',
              )
            else
              ...tenants.map(
                    (tenant) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InfoRow(
                        label: 'Tenant',
                        value: tenant.name,
                      ),
                    ),
              ),

            const SizedBox(height: 8),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.event_outlined,
                ),
                title: const Text(
                  'Due Date',
                ),
                subtitle: Text(
                  _formatDate(dueDate),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: isGenerating
                    ? null
                    : onSelectDueDate,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'The system will calculate the rent from the '
                  'tenant tenancy period and applicable rent-rate '
                  'history. If the tenancy or rent rate changes '
                  'during the month, separate rent records may '
                  'be generated.',
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isGenerating || !hasTenant
                    ? null
                    : onGenerate,
                icon: isGenerating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.auto_awesome,
                ),
                label: Text(
                  isGenerating
                      ? 'Generating...'
                      : hasTenant
                      ? 'Generate Monthly Rent'
                      : 'No Active Tenant',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HISTORY
// ============================================================================

class _MonthlyRentHistorySection extends ConsumerWidget {
  final String unitId;
  final String ownerId;

  const _MonthlyRentHistorySection({
    required this.unitId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context,
      WidgetRef ref,) {
    final historyAsync = ref.watch(
      unitMonthlyRentHistoryProvider(
        (
        unitId: unitId,
        ownerId: ownerId,
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: historyAsync.when(
          loading: () {
            return const _LoadingRow(
              label: 'Monthly Rent History',
            );
          },
          error: (error, stackTrace) {
            return const _InfoRow(
              label: 'Monthly Rent History',
              value: 'Unable to load history.',
            );
          },
          data: (history) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Rent History',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 16),
                if (history.isEmpty)
                  const Text(
                    'No monthly rent records found.',
                  )
                else
                  ...List.generate(
                    history.length,
                        (index) {
                      final rent = history[index];

                      return Column(
                        children: [
                          if (index > 0)
                            const Divider(
                              height: 28,
                            ),
                          _MonthlyHistoryItem(
                            monthlyRent: rent,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// HISTORY ITEM
// ============================================================================

class _MonthlyHistoryItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _MonthlyHistoryItem({
    required this.monthlyRent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatMonth(
                  monthlyRent.billingPeriodStart,
                ),
                style: Theme
                    .of(context)
                    .textTheme
                    .titleSmall,
              ),
            ),
            _StatusChip(
              status: monthlyRent.status,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '৳ ${_formatAmount(monthlyRent.amount)}',
          style: Theme
              .of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Charge: '
              '${_formatDate(monthlyRent.chargePeriodStart)}'
              ' - '
              '${_formatDate(monthlyRent.chargePeriodEnd)}',
          style: Theme
              .of(context)
              .textTheme
              .bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Due: ${_formatDate(monthlyRent.dueDate)}',
          style: Theme
              .of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS
// ============================================================================

class _StatusChip extends StatelessWidget {
  final MonthlyRentStatus status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    final isPaid = status == MonthlyRentStatus.paid;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isPaid
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        _statusLabel(status),
        style: Theme
            .of(context)
            .textTheme
            .labelSmall,
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? Theme
        .of(context)
        .textTheme
        .titleMedium
        ?.copyWith(
      fontWeight: FontWeight.bold,
    )
        : Theme
        .of(context)
        .textTheme
        .bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .labelMedium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING
// ============================================================================

class _LoadingRow extends StatelessWidget {
  final String label;

  const _LoadingRow({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme
              .of(context)
              .textTheme
              .titleMedium,
        ),
        const Spacer(),
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR
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

// ============================================================================
// DATE HELPERS
// ============================================================================

DateTime _firstDayOfMonth(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    1,
  );
}

DateTime _firstDayOfNextMonth(DateTime date) {
  if (date.month == 12) {
    return DateTime(
      date.year + 1,
      1,
      1,
    );
  }

  return DateTime(
    date.year,
    date.month + 1,
    1,
  );
}

DateTime _defaultDueDate(DateTime date) {
  final start = _firstDayOfMonth(date);

  return DateTime(
    start.year,
    start.month,
    7,
  );
}

DateTime _dateOnly(DateTime date) {
  final local = date.toLocal();

  return DateTime(
    local.year,
    local.month,
    local.day,
  );
}

DateTime _maxDate(DateTime first,
    DateTime second,) {
  return first.isAfter(second) ? first : second;
}

DateTime _minDate(DateTime first,
    DateTime second,) {
  return first.isBefore(second) ? first : second;
}

String _dateKey(DateTime date) {
  final local = _dateOnly(date);

  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

// ============================================================================
// FORMATTERS
// ============================================================================

String _formatMonth(DateTime dateTime) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[dateTime.month - 1]} ${dateTime.year}';
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();

  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}

String _statusLabel(MonthlyRentStatus status) {
  switch (status) {
    case MonthlyRentStatus.unpaid:
      return 'Unpaid';

    case MonthlyRentStatus.partiallyPaid:
      return 'Partially Paid';

    case MonthlyRentStatus.paid:
      return 'Paid';

    case MonthlyRentStatus.overdue:
      return 'Overdue';

    case MonthlyRentStatus.cancelled:
      return 'Cancelled';
  }
}