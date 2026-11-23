// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../billing/presentation/providers/tenancy_billing_target_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/generate_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
import '../providers/monthly_rent_provider.dart';
import '../widgets/rent_ui_helpers.dart';

class MonthlyRentScreen extends ConsumerStatefulWidget {
  final String unitId;

  const MonthlyRentScreen({super.key, required this.unitId});

  @override
  ConsumerState<MonthlyRentScreen> createState() => _MonthlyRentScreenState();
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

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final unit = await ref.read(unitByIdProvider(widget.unitId).future);
      if (unit == null) {
        throw StateError('Unit not found.');
      }

      final property = await ref.read(
        propertyByIdProvider(unit.propertyId).future,
      );
      if (property == null) {
        throw StateError('Property not found.');
      }

      final periodArgs = (
      unitId: unit.id,
      ownerId: property.ownerId,
      billingPeriodStart: _billingPeriodStart,
      );

      if (forceRefresh) {
        ref.invalidate(monthlyRentByUnitAndPeriodProvider(periodArgs));
        ref.invalidate(
          unitMonthlyRentHistoryProvider((
          unitId: unit.id,
          ownerId: property.ownerId,
          )),
        );
      }

      // Fetch active tenants and period rents concurrently.
      final results = await Future.wait<dynamic>([
        ref.read(getActiveTenantsByUnitIdProvider)(unit.id),
        ref.read(monthlyRentByUnitAndPeriodProvider(periodArgs).future),
      ]);

      var activeTenants = results[0] as List<Tenant>;
      final monthlyRents = results[1] as List<MonthlyRent>;

      if (activeTenants.isEmpty && unit.status == UnitStatus.occupied) {
        final snap = await FirebaseFirestore.instance
            .collection('tenants')
            .where('unitId', isEqualTo: unit.id)
            .where('status', isEqualTo: 'active')
            .limit(10)
            .get();

        activeTenants = snap.docs.map(TenantModel.fromFirestore).toList();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _unit = unit;
        _property = property;
        _activeTenants = activeTenants;
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

    final lastDay = end.subtract(const Duration(days: 1));
    final desiredDay = _dueDate.day;
    final safeDay = desiredDay > lastDay.day ? lastDay.day : desiredDay;

    setState(() {
      _billingPeriodStart = start;
      _billingPeriodEnd = end;
      _dueDate = DateTime(start.year, start.month, safeDay);
    });

    await _loadBillingPeriodData();
  }

  Future<void> _loadBillingPeriodData({bool invalidateFirst = false}) async {
    final unit = _unit;
    final property = _property;
    if (unit == null || property == null) {
      return;
    }

    final periodArgs = (
    unitId: unit.id,
    ownerId: property.ownerId,
    billingPeriodStart: _billingPeriodStart,
    );

    if (invalidateFirst) {
      ref.invalidate(monthlyRentByUnitAndPeriodProvider(periodArgs));
    }

    try {
      final monthlyRents = await ref.read(
        monthlyRentByUnitAndPeriodProvider(periodArgs).future,
      );

      if (!mounted) {
        return;
      }

      setState(() => _monthlyRents = monthlyRents);
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Unable to load monthly rent: $error');
    }
  }

  Future<void> _selectDueDate() async {
    if (_isGenerating) {
      return;
    }

    final lastDay = _billingPeriodEnd.subtract(const Duration(days: 1));

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

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _generateMonthlyRent() async {
    if (_isGenerating) {
      return;
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      GrihoFeedback.showError(
        context,
        'Unit or property information is unavailable.',
      );
      return;
    }

    if (_dueDate.isBefore(_billingPeriodStart) ||
        !_dueDate.isBefore(_billingPeriodEnd)) {
      GrihoFeedback.showError(
        context,
        'Due date must be within the selected billing month.',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final resolver = ref.read(tenancyBillingTargetResolverProvider);

      final tenancyTargets = await resolver.resolve(
        ownerId: property.ownerId,
        propertyId: property.id,
        billingPeriodStart: _billingPeriodStart,
        billingPeriodEnd: _billingPeriodEnd,
        currentTenants: _activeTenants,
        units: [(unitId: unit.id.trim(), floorId: unit.floorNumber.toString())],
      );

      if (tenancyTargets.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _isGenerating = false);
        GrihoFeedback.showError(
          context,
          'No tenancy period overlaps the selected billing month.',
        );
        return;
      }

      final generateMonthlyRent = ref.read(generateMonthlyRentProvider);
      final generatedRents = <MonthlyRent>[];

      for (final target in tenancyTargets) {
        if (target.unitId != unit.id) {
          continue;
        }

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

      if (!mounted) {
        return;
      }

      // Invalidate cache first so freshly generated records are displayed immediately.
      await _loadBillingPeriodData(invalidateFirst: true);

      if (!mounted) {
        return;
      }

      ref.invalidate(
        unitMonthlyRentHistoryProvider((
        unitId: unit.id,
        ownerId: property.ownerId,
        )),
      );

      setState(() => _isGenerating = false);

      if (generatedRents.isEmpty) {
        GrihoFeedback.showInfo(
          context,
          'No new rent records were generated. Records may already exist for the selected period.',
        );
        return;
      }

      GrihoFeedback.showSuccess(
        context,
        '${generatedRents.length} monthly rent ${generatedRents.length == 1 ? 'record' : 'records'} generated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isGenerating = false);
      GrihoFeedback.showError(
        context,
        'Unable to generate monthly rent: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monthly Rent')),
        body: const GrihoLoadingView(message: 'Loading monthly rent...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monthly Rent')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load monthly rent',
              subtitle: _errorMessage!,
              actionLabel: 'Retry',
              onAction: () => _loadData(forceRefresh: true),
            ),
          ),
        ),
      );
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monthly Rent')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.home_2,
              title: 'Information not found',
              subtitle: 'Required unit or property information was not found.',
            ),
          ),
        ),
      );
    }

    final hasGeneratedRent = _monthlyRents.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Monthly Rent Invoice')),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
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
              _MonthlyRentSummaryCard(monthlyRents: _monthlyRents),
              const SizedBox(height: 16),
              _GeneratedMonthlyRentsCard(monthlyRents: _monthlyRents),
              const SizedBox(height: 16),
            ],
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
        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                  Iconsax.receipt_item,
                  size: 24,
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
              RentOccupancyChip(isOccupied: hasActiveTenant),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Iconsax.user,
                size: 16,
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final periodEnd = billingPeriodEnd.subtract(const Duration(days: 1));

    return Card(
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
                  Iconsax.calendar_1,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatRentMonth(billingPeriodStart),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatRentDate(billingPeriodStart)} to ${formatRentDate(periodEnd)}',
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

class _MonthlyRentSummaryCard extends StatelessWidget {
  final List<MonthlyRent> monthlyRents;

  const _MonthlyRentSummaryCard({required this.monthlyRents});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = monthlyRents.fold<double>(
      0.0,
          (sum, rent) => sum + rent.amount,
    );
    final chargeableDays = monthlyRents.fold<int>(
      0,
          (days, rent) => days + rent.chargeableDays,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GrihoColors.emerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Generated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: GrihoColors.emerald,
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
                      '৳ ${formatRentAmount(total)}',
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

class _GeneratedMonthlyRentsCard extends StatelessWidget {
  final List<MonthlyRent> monthlyRents;

  const _GeneratedMonthlyRentsCard({required this.monthlyRents});

  @override
  Widget build(BuildContext context) {
    final sorted = [...monthlyRents]
      ..sort((a, b) => a.chargePeriodStart.compareTo(b.chargePeriodStart));

    return GrihoSectionCard(
      title: 'Invoice Records',
      icon: Iconsax.receipt_item,
      children: [
        for (var index = 0; index < sorted.length; index++) ...[
          _GeneratedRentItem(monthlyRent: sorted[index]),
          if (index != sorted.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _GeneratedRentItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _GeneratedRentItem({required this.monthlyRent});

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
              '৳ ${formatRentAmount(monthlyRent.amount)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            MonthlyRentStatusChip(status: monthlyRent.status),
          ],
        ),
        const SizedBox(height: 8),
        _DataRow(
          label: 'Charge Period',
          value:
          '${formatRentDate(monthlyRent.chargePeriodStart)} - ${formatRentDate(monthlyRent.chargePeriodEnd)}',
        ),
        _DataRow(
          label: 'Billing Ratio',
          value:
          '${monthlyRent.chargeableDays} of ${monthlyRent.daysInBillingPeriod} days',
        ),
        _DataRow(
          label: 'Monthly Rate',
          value: '৳ ${formatRentAmount(monthlyRent.monthlyRate)}',
        ),
        _DataRow(
          label: 'Payment Due Date',
          value: formatRentDate(monthlyRent.dueDate),
        ),
      ],
    );
  }
}

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

    return GrihoSectionCard(
      title: hasGeneratedRent
          ? 'Check / Complete Monthly Rent'
          : 'Generate Monthly Rent',
      subtitle:
      'Calculate rent using the tenancy periods and applicable rent rates. Existing records are skipped automatically.',
      icon: Iconsax.flash_1,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isGenerating ? null : onSelectDueDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Payment Due Date',
              prefixIcon: Icon(
                Iconsax.calendar_1,
                color: GrihoColors.emerald,
                size: 20,
              ),
              suffixIcon: Icon(Iconsax.arrow_right_3, size: 16),
            ),
            child: Text(
              formatRentDate(dueDate),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Iconsax.info_circle,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If a tenancy starts or ends during the month, the amount is automatically prorated according to the tenancy dates.',
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
        GrihoPrimaryButton(
          label: isGenerating
              ? 'Calculating & Generating...'
              : hasGeneratedRent
              ? 'Check / Generate Missing Rent'
              : hasTenant
              ? 'Generate Monthly Rent'
              : 'No Active Tenant',
          icon: Iconsax.flash_1,
          isLoading: isGenerating,
          onPressed: (!hasTenant && !hasGeneratedRent) ? null : onGenerate,
        ),
      ],
    );
  }
}

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
      unitMonthlyRentHistoryProvider((unitId: unitId, ownerId: ownerId)),
    );

    return GrihoSectionCard(
      title: 'Monthly Rent History',
      icon: Iconsax.clock,
      children: [
        historyAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Unable to load history: $error'),
          data: (history) {
            if (history.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  _MonthlyHistoryItem(monthlyRent: history[index]),
                  if (index != history.length - 1) const Divider(height: 20),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonthlyHistoryItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _MonthlyHistoryItem({required this.monthlyRent});

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
            Iconsax.clock,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatRentMonth(monthlyRent.billingPeriodStart),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Due ${formatRentDate(monthlyRent.dueDate)}',
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
              '৳ ${formatRentAmount(monthlyRent.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            MonthlyRentStatusChip(status: monthlyRent.status),
          ],
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

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

DateTime _firstDayOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime _firstDayOfNextMonth(DateTime date) =>
    DateTime(date.year, date.month + 1, 1);

DateTime _defaultDueDate(DateTime date) {
  final start = _firstDayOfMonth(date);
  return DateTime(start.year, start.month, 7);
}
