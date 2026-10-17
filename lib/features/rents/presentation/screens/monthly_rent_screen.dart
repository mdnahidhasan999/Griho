import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../billing/presentation/providers/tenancy_billing_target_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/generate_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
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
  List<MonthlyRent> _monthlyRents = const [];

  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  DateTime _billingPeriodStart = _firstDayOfMonth(DateTime.now());
  DateTime _billingPeriodEnd = _firstDayOfNextMonth(DateTime.now());
  DateTime _dueDate = _defaultDueDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ==========================================================================
  // LOAD DATA
  // ==========================================================================

  Future<void> _loadData() async {
    if (!mounted) return;

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

      final getActiveTenants = ref.read(
        getActiveTenantsByUnitIdProvider,
      );

      final activeTenants = await getActiveTenants(unit.id);

      final monthlyRents = await ref.read(
        monthlyRentByUnitAndPeriodProvider((
        unitId: unit.id,
        ownerId: property.ownerId,
        billingPeriodStart: _billingPeriodStart,
        )).future,
      );

      if (!mounted) return;

      setState(() {
        _unit = unit;
        _property = property;
        _activeTenants = activeTenants;
        _monthlyRents = monthlyRents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  // ==========================================================================
  // BILLING MONTH SELECTOR
  // ==========================================================================

  Future<void> _selectBillingMonth() async {
    if (_isGenerating) return;

    final selected = await showDatePicker(
      context: context,
      initialDate: _billingPeriodStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select billing month',
    );

    if (!mounted || selected == null) return;

    final start = _firstDayOfMonth(selected);
    final end = _firstDayOfNextMonth(selected);

    final lastDay = end.subtract(const Duration(days: 1));
    final desiredDay = _dueDate.day;
    final safeDay = desiredDay > lastDay.day
        ? lastDay.day
        : desiredDay;

    setState(() {
      _billingPeriodStart = start;
      _billingPeriodEnd = end;
      _dueDate = DateTime(start.year, start.month, safeDay);
    });

    await _loadBillingPeriodData();
  }

  Future<void> _loadBillingPeriodData() async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) return;

    try {
      final monthlyRents = await ref.read(
        monthlyRentByUnitAndPeriodProvider((
        unitId: unit.id,
        ownerId: property.ownerId,
        billingPeriodStart: _billingPeriodStart,
        )).future,
      );

      if (!mounted) return;

      setState(() {
        _monthlyRents = monthlyRents;
      });
    } catch (error) {
      if (!mounted) return;

      _showError('Unable to load monthly rent: $error');
    }
  }

  // ==========================================================================
  // DUE DATE SELECTOR
  // ==========================================================================

  Future<void> _selectDueDate() async {
    if (_isGenerating) return;

    final lastDay = _billingPeriodEnd.subtract(
      const Duration(days: 1),
    );

    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_billingPeriodStart)
          ? _billingPeriodStart
          : _dueDate.isAfter(lastDay)
          ? lastDay
          : _dueDate,
      firstDate: _billingPeriodStart,
      lastDate: lastDay,
      helpText: 'Select rent due date',
    );

    if (!mounted || selected == null) return;

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
    if (_isGenerating) return;

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      _showError('Unit or property information is unavailable.');
      return;
    }

    if (_dueDate.isBefore(_billingPeriodStart) ||
        !_dueDate.isBefore(_billingPeriodEnd)) {
      _showError(
        'Due date must be within the selected billing month.',
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Resolve tenancy periods using the shared resolver.
      // This includes historical and current tenancies.
      final resolver = ref.read(
        tenancyBillingTargetResolverProvider,
      );

      final tenancyTargets = await resolver.resolve(
        ownerId: property.ownerId,
        propertyId: property.id,
        billingPeriodStart: _billingPeriodStart,
        billingPeriodEnd: _billingPeriodEnd,
        currentTenants: _activeTenants,
        units: [
          (
          unitId: unit.id.trim(),
          floorId: unit.floorNumber.toString(),
          ),
        ],
      );

      if (tenancyTargets.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isGenerating = false;
        });

        _showError(
          'No tenancy period overlaps the selected billing month.',
        );
        return;
      }

      final generateMonthlyRent = ref.read(
        generateMonthlyRentProvider,
      );

      final generatedRents = <MonthlyRent>[];

      for (final target in tenancyTargets) {
        // Only generate rent for the unit opened on this screen.
        if (target.unitId != unit.id) continue;

        final request = GenerateMonthlyRentRequest(
          ownerId: property.ownerId,
          propertyId: property.id,
          unitId: target.unitId,
          tenantId: target.tenantId,
          tenantUserId: target.tenantUserId,
          billingPeriodStart: _billingPeriodStart,
          billingPeriodEnd: _billingPeriodEnd,
          dueDate: _dueDate,
          tenancyStart: target.tenancyStart,
          tenancyEnd: target.tenancyEnd,
        );

        final rents = await generateMonthlyRent(request);
        generatedRents.addAll(rents);
      }

      if (!mounted) return;

      // Refresh the selected billing period.
      await _loadBillingPeriodData();

      if (!mounted) return;

      // Refresh the complete rent history.
      ref.invalidate(
        unitMonthlyRentHistoryProvider((
        unitId: unit.id,
        ownerId: property.ownerId,
        )),
      );

      setState(() {
        _isGenerating = false;
      });

      if (generatedRents.isEmpty) {
        _showError(
          'No new rent records were generated. '
              'Records may already exist for the selected tenancy periods.',
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
      });

      _showError('Unable to generate monthly rent: $error');
    }
  }

  // ==========================================================================
  // ERROR MESSAGE
  // ==========================================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          child: Text('Required information not found.'),
        ),
      );
    }

    final hasGeneratedRent = _monthlyRents.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Monthly Rent Invoice',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _UnitPropertyOverviewCard(
              unit: unit,
              property: property,
              activeTenants: _activeTenants,
            ),
            const SizedBox(height: 16),

            _BillingPeriodSelectorCard(
              billingPeriodStart: _billingPeriodStart,
              billingPeriodEnd: _billingPeriodEnd,
              isGenerating: _isGenerating,
              onSelect: _selectBillingMonth,
            ),
            const SizedBox(height: 16),

            if (hasGeneratedRent) ...[
              _MonthlyRentSummaryCard(
                monthlyRents: _monthlyRents,
              ),
              const SizedBox(height: 16),
              _GeneratedMonthlyRentsCard(
                monthlyRents: _monthlyRents,
              ),
              const SizedBox(height: 16),
            ],

            // Keep this card visible even when some rent records exist.
            // The use case must skip existing records and create only missing
            // tenancy segments.
            _GenerateMonthlyRentCard(
              tenants: _activeTenants,
              dueDate: _dueDate,
              isGenerating: _isGenerating,
              onSelectDueDate: _selectDueDate,
              onGenerate: _generateMonthlyRent,
              hasGeneratedRent: hasGeneratedRent,
            ),

            const SizedBox(height: 24),

            _MonthlyRentHistorySection(
              unitId: unit.id,
              ownerId: property.ownerId,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UNIT & PROPERTY OVERVIEW
// ============================================================================

class _UnitPropertyOverviewCard extends StatelessWidget {
  final Unit unit;
  final Property property;
  final List<Tenant> activeTenants;

  const _UnitPropertyOverviewCard({
    required this.unit,
    required this.property,
    required this.activeTenants,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveTenant = activeTenants.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
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
                      'Unit ${unit.unitNumber}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${property.name} • Floor ${unit.floorNumber}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _OccupancyChip(
                isOccupied: hasActiveTenant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Tenant: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  hasActiveTenant
                      ? activeTenants.map((t) => t.name).join(', ')
                      : 'No tenant assigned',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OccupancyChip extends StatelessWidget {
  final bool isOccupied;

  const _OccupancyChip({
    required this.isOccupied,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOccupied ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOccupied ? 'Occupied' : 'Vacant',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isOccupied
              ? Colors.green.shade800
              : Colors.blue.shade800,
        ),
      ),
    );
  }
}

// ============================================================================
// BILLING PERIOD SELECTOR
// ============================================================================

class _BillingPeriodSelectorCard extends StatelessWidget {
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final bool isGenerating;
  final VoidCallback onSelect;

  const _BillingPeriodSelectorCard({
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.isGenerating,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periodEnd = billingPeriodEnd.subtract(
      const Duration(days: 1),
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isGenerating ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMonth(billingPeriodStart),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(billingPeriodStart)} to '
                          '${_formatDate(periodEnd)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Change Month',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
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
// MONTHLY RENT SUMMARY
// ============================================================================

class _MonthlyRentSummaryCard extends StatelessWidget {
  final List<MonthlyRent> monthlyRents;

  const _MonthlyRentSummaryCard({
    required this.monthlyRents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = monthlyRents.fold<double>(
      0,
          (sum, rent) => sum + rent.amount,
    );

    final chargeableDays = monthlyRents.fold<int>(
      0,
          (sum, rent) => sum + rent.chargeableDays,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Billing Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Generated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Rent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳ ${_formatAmount(total)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chargeable Days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$chargeableDays Days',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
    final theme = Theme.of(context);

    final sorted = [...monthlyRents]
      ..sort(
            (a, b) => a.chargePeriodStart.compareTo(b.chargePeriodStart),
      );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Records',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < sorted.length; index++) ...[
            _GeneratedRentItem(
              monthlyRent: sorted[index],
            ),
            if (index != sorted.length - 1)
              const Divider(height: 24),
          ],
        ],
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '৳ ${_formatAmount(monthlyRent.amount)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            _StatusChip(status: monthlyRent.status),
          ],
        ),
        const SizedBox(height: 8),
        _DataRow(
          label: 'Charge Period',
          value: '${_formatDate(monthlyRent.chargePeriodStart)} - '
              '${_formatDate(monthlyRent.chargePeriodEnd)}',
        ),
        _DataRow(
          label: 'Billing Ratio',
          value: '${monthlyRent.chargeableDays} of '
              '${monthlyRent.daysInBillingPeriod} days',
        ),
        _DataRow(
          label: 'Monthly Rate',
          value: '৳ ${_formatAmount(monthlyRent.monthlyRate)}',
        ),
        _DataRow(
          label: 'Payment Due Date',
          value: _formatDate(monthlyRent.dueDate),
        ),
      ],
    );
  }
}

// ============================================================================
// GENERATE RENT CARD
// ============================================================================

class _GenerateMonthlyRentCard extends StatelessWidget {
  final List<Tenant> tenants;
  final DateTime dueDate;
  final bool isGenerating;
  final bool hasGeneratedRent;
  final VoidCallback onSelectDueDate;
  final VoidCallback onGenerate;

  const _GenerateMonthlyRentCard({
    required this.tenants,
    required this.dueDate,
    required this.isGenerating,
    required this.onSelectDueDate,
    required this.onGenerate,
    required this.hasGeneratedRent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTenant = tenants.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasGeneratedRent
                      ? 'Check / Complete Monthly Rent'
                      : 'Generate Monthly Rent',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Calculate rent using the tenancy periods and applicable '
                'rent rates. Existing records should be skipped by the '
                'generation use case.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isGenerating ? null : onSelectDueDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Payment Due Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_outlined),
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(
                _formatDate(dueDate),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If a tenancy starts or ends during the month, '
                        'the amount should be prorated according to the '
                        'tenancy dates.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: isGenerating || !hasTenant && !hasGeneratedRent
                  ? null
                  : onGenerate,
              icon: isGenerating
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.flash_on_rounded,
                size: 20,
              ),
              label: Text(
                isGenerating
                    ? 'Calculating & Generating...'
                    : hasGeneratedRent
                    ? 'Check / Generate Missing Rent'
                    : hasTenant
                    ? 'Generate Monthly Rent'
                    : 'No Active Tenant',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MONTHLY RENT HISTORY
// ============================================================================

class _MonthlyRentHistorySection extends ConsumerWidget {
  final String unitId;
  final String ownerId;

  const _MonthlyRentHistorySection({
    required this.unitId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final historyAsync = ref.watch(
      unitMonthlyRentHistoryProvider((
      unitId: unitId,
      ownerId: ownerId,
      )),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Rent History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          historyAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                Text(
                  'Unable to load history: $error',
                ),
            data: (history) {
              if (history.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    child: Text(
                      'No past rent records found for this unit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < history.length; index++) ...[
                    _MonthlyHistoryItem(
                      monthlyRent: history[index],
                    ),
                    if (index != history.length - 1)
                      const Divider(height: 20),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthlyHistoryItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _MonthlyHistoryItem({
    required this.monthlyRent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.history_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatMonth(monthlyRent.billingPeriodStart),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Due ${_formatDate(monthlyRent.dueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳ ${_formatAmount(monthlyRent.amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            _StatusChip(
              status: monthlyRent.status,
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================

class _StatusChip extends StatelessWidget {
  final MonthlyRentStatus status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _statusStyle(MonthlyRentStatus status) {
    switch (status) {
      case MonthlyRentStatus.paid:
        return ('Paid', Colors.green.shade800);
      case MonthlyRentStatus.partiallyPaid:
        return ('Partially Paid', Colors.amber.shade900);
      case MonthlyRentStatus.unpaid:
        return ('Unpaid', Colors.blue.shade800);
      case MonthlyRentStatus.overdue:
        return ('Overdue', Colors.red.shade800);
      case MonthlyRentStatus.cancelled:
        return ('Cancelled', Colors.grey.shade700);
    }
  }
}

// ============================================================================
// DATA ROW
// ============================================================================

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DATE HELPERS
// ============================================================================

DateTime _firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month, 1);
}

DateTime _firstDayOfNextMonth(DateTime date) {
  return DateTime(date.year, date.month + 1, 1);
}

DateTime _defaultDueDate(DateTime date) {
  final start = _firstDayOfMonth(date);
  return DateTime(start.year, start.month, 7);
}

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

String _formatAmount(num? amount) {
  if (amount == null) return '0.00';

  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
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