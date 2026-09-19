import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';

import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';

import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';

import '../../domain/entities/create_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
import '../providers/monthly_rent_provider.dart';
import '../providers/rent_rate_provider.dart';

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
  Tenant? _tenant;
  MonthlyRent? _currentMonthlyRent;

  bool _isLoading = true;
  bool _isCreating = false;

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

      final monthlyRent = await ref.read(
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
        _tenant = tenants.isEmpty ? null : tenants.first;
        _currentMonthlyRent = monthlyRent;
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

    await _loadCurrentMonthlyRent();
  }

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

  Future<void> _loadCurrentMonthlyRent() async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return;
    }

    try {
      final monthlyRent = await ref.read(
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
        _currentMonthlyRent = monthlyRent;
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

  Future<void> _createMonthlyRent() async {
    if (_isCreating) {
      return;
    }

    final unit = _unit;
    final property = _property;
    final tenant = _tenant;

    if (unit == null || property == null) {
      _showError(
        'Unit or property information is unavailable.',
      );
      return;
    }

    if (tenant == null) {
      _showError(
        'This unit does not have an active tenant.',
      );
      return;
    }

    if (tenant.userId == null ||
        tenant.userId!.trim().isEmpty) {
      _showError(
        'The tenant account is not linked.',
      );
      return;
    }

    if (_currentMonthlyRent != null) {
      _showError(
        'Monthly rent already exists for this billing period.',
      );
      return;
    }

    if (_dueDate.isBefore(_billingPeriodStart)) {
      _showError(
        'Due date cannot be before the billing period starts.',
      );
      return;
    }

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

    if (rentRate == null) {
      _showError(
        'No current rent rate is configured for this unit.',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final request = CreateMonthlyRentRequest(
      ownerId: property.ownerId,
      propertyId: property.id,
      unitId: unit.id,
      tenantId: tenant.id,
      tenantUserId: tenant.userId,
      rentRateId: rentRate.id,
      amount: rentRate.amount,
      billingPeriodStart: _billingPeriodStart,
      billingPeriodEnd: _billingPeriodEnd,
      dueDate: _dueDate,
      status: MonthlyRentStatus.unpaid,
    );

    final controller = ref.read(
      monthlyRentControllerProvider.notifier,
    );

    final result = await controller.createMonthlyRent(
      request: request,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isCreating = false;
    });

    if (result == null) {
      final state = ref.read(
        monthlyRentControllerProvider,
      );

      final error = state.whenOrNull(
        error: (error, stackTrace) {
          return error.toString();
        },
      );

      _showError(
        error ?? 'Unable to create monthly rent.',
      );

      return;
    }

    setState(() {
      _currentMonthlyRent = result;
    });

    ref.invalidate(
      monthlyRentByUnitAndPeriodProvider(
        (
        unitId: unit.id,
        ownerId: property.ownerId,
        billingPeriodStart: _billingPeriodStart,
        ),
      ),
    );

    ref.invalidate(
      unitMonthlyRentHistoryProvider(
        (
        unitId: unit.id,
        ownerId: property.ownerId,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Monthly rent created successfully.',
        ),
      ),
    );
  }

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
              onTap: _isCreating
                  ? null
                  : _selectBillingMonth,
            ),

            const SizedBox(height: 16),

            if (_currentMonthlyRent != null)
              _ExistingMonthlyRentCard(
                monthlyRent: _currentMonthlyRent!,
              )
            else
              _CreateMonthlyRentCard(
                tenant: _tenant,
                dueDate: _dueDate,
                isCreating: _isCreating,
                onSelectDueDate: _selectDueDate,
                onCreate: _createMonthlyRent,
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

class _ExistingMonthlyRentCard extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _ExistingMonthlyRentCard({
    required this.monthlyRent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly Rent',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                _StatusChip(
                  status: monthlyRent.status,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              '৳ ${_formatAmount(monthlyRent.amount)}',
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            _InfoRow(
              label: 'Due Date',
              value: _formatDate(
                monthlyRent.dueDate,
              ),
            ),

            const SizedBox(height: 8),

            _InfoRow(
              label: 'Status',
              value: _statusLabel(
                monthlyRent.status,
              ),
            ),

            const SizedBox(height: 8),

            _InfoRow(
              label: 'Created',
              value: _formatDateTime(
                monthlyRent.createdAt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateMonthlyRentCard extends StatelessWidget {
  final Tenant? tenant;
  final DateTime dueDate;
  final bool isCreating;
  final VoidCallback onSelectDueDate;
  final VoidCallback onCreate;

  const _CreateMonthlyRentCard({
    required this.tenant,
    required this.dueDate,
    required this.isCreating,
    required this.onSelectDueDate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final hasTenant = tenant != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Monthly Rent',
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
              _InfoRow(
                label: 'Tenant',
                value: tenant!.name,
              ),

            const SizedBox(height: 16),

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
                onTap: isCreating
                    ? null
                    : onSelectDueDate,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'The monthly rent amount will be taken from '
                  'the current rent rate of this unit and '
                  'frozen in this monthly billing record.',
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCreating || !hasTenant
                    ? null
                    : onCreate,
                icon: isCreating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.add,
                ),
                label: Text(
                  isCreating
                      ? 'Creating...'
                      : hasTenant
                      ? 'Create Monthly Rent'
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
              crossAxisAlignment:
              CrossAxisAlignment.start,
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

class _MonthlyHistoryItem extends StatelessWidget {
  final MonthlyRent monthlyRent;

  const _MonthlyHistoryItem({
    required this.monthlyRent,
  });

  @override
  Widget build(BuildContext context) {
    final periodEnd = monthlyRent.billingPeriodEnd
        .subtract(
      const Duration(days: 1),
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
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
          '${_formatDate(monthlyRent.billingPeriodStart)}'
              ' - '
              '${_formatDate(periodEnd)}',
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
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
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium,
          ),
        ),
      ],
    );
  }
}

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

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();

  return '${_formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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