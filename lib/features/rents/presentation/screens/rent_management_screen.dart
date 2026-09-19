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
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';

class RentManagementScreen extends ConsumerStatefulWidget {
  final String unitId;

  const RentManagementScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<RentManagementScreen> createState() =>
      _RentManagementScreenState();
}

class _RentManagementScreenState extends ConsumerState<RentManagementScreen> {
  Unit? _unit;
  Property? _property;
  List<Tenant> _activeTenants = [];
  RentRate? _currentRentRate;

  bool _isLoading = true;
  bool _isChangingBulkRent = false;

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

  // ============================================================
  // UNIT RENT
  // ============================================================

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

  // ============================================================
  // FLOOR RENT
  // ============================================================

  Future<void> _openFloorRentChange() async {
    final unit = _unit;

    if (unit == null) {
      return;
    }

    final result = await _showBulkRentAdjustmentDialog(
      title: 'Change Floor Rent',
      description:
      'This will adjust the rent for all occupied units '
          'on Floor ${unit.floorNumber}.',
    );

    if (!mounted || result == null) {
      return;
    }

    await _changeFloorRent(
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
    );
  }

  Future<void> _changeFloorRent({
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return;
    }

    if (_isChangingBulkRent) {
      return;
    }

    setState(() {
      _isChangingBulkRent = true;
    });

    final controller =
    ref.read(rentRateControllerProvider.notifier);

    final result = await controller.changeFloorRent(
      propertyId: property.id,
      floorNumber: unit.floorNumber,
      ownerId: property.ownerId,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isChangingBulkRent = false;
    });

    if (result == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(
        error: (error, stackTrace) => error.toString(),
      );

      _showError(
        error ?? 'Unable to change floor rent.',
      );

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

    if (!mounted) {
      return;
    }

    final action =
    adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    _showSuccess(
      'Floor rent $action by '
          '৳${_formatAmount(amount)} for '
          '${result.length} occupied unit(s).',
    );
  }

  // ============================================================
  // PROPERTY RENT
  // ============================================================

  Future<void> _openPropertyRentChange() async {
    final property = _property;

    if (property == null) {
      return;
    }

    final result = await _showBulkRentAdjustmentDialog(
      title: 'Change Property Rent',
      description:
      'This will adjust the rent for all occupied units '
          'in ${property.name}.',
    );

    if (!mounted || result == null) {
      return;
    }

    await _changePropertyRent(
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
    );
  }

  Future<void> _changePropertyRent({
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return;
    }

    if (_isChangingBulkRent) {
      return;
    }

    setState(() {
      _isChangingBulkRent = true;
    });

    final controller =
    ref.read(rentRateControllerProvider.notifier);

    final result =
    await controller.changePropertyRent(
      propertyId: property.id,
      ownerId: property.ownerId,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isChangingBulkRent = false;
    });

    if (result == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(
        error: (error, stackTrace) => error.toString(),
      );

      _showError(
        error ?? 'Unable to change property rent.',
      );

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

    if (!mounted) {
      return;
    }

    final action =
    adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    _showSuccess(
      'Property rent $action by '
          '৳${_formatAmount(amount)} for '
          '${result.length} occupied unit(s).',
    );
  }

  // ============================================================
  // BULK RENT ADJUSTMENT DIALOG
  // ============================================================

  Future<_RentAdjustmentResult?>
  _showBulkRentAdjustmentDialog({
    required String title,
    required String description,
  }) {
    return showDialog<_RentAdjustmentResult>(
      context: context,
      builder: (_) {
        return _BulkRentAdjustmentDialog(
          title: title,
          description: description,
        );
      },
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  // ============================================================
  // RENT HISTORY
  // ============================================================

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

  // ============================================================
  // MONTHLY RENT
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Rent Management',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Rent Management',
          ),
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
          title: const Text(
            'Rent Management',
          ),
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
        title: const Text(
          'Rent Management',
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
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
                  hasActiveTenant:
                  _activeTenants.isNotEmpty,
                  onChangeRent: _openRentChange,
                ),

                const SizedBox(height: 16),

                _RentScopeCard(
                  floorNumber: unit.floorNumber,
                  propertyName: property.name,
                  onUnitRent: _openRentChange,
                  onFloorRent:
                  _openFloorRentChange,
                  onPropertyRent:
                  _openPropertyRentChange,
                  enabled: !_isChangingBulkRent,
                ),

                const SizedBox(height: 16),

                if (_currentRentRate != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                      _isChangingBulkRent
                          ? null
                          : _openMonthlyRent,
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
                    onPressed:
                    _isChangingBulkRent
                        ? null
                        : _openRentHistory,
                    icon: const Icon(
                      Icons.history,
                    ),
                    label: const Text(
                      'View Rent History',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isChangingBulkRent)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(
                            height: 16,
                          ),
                          Text(
                            'Updating rent...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// BULK RENT ADJUSTMENT DIALOG
// ================================================================

class _BulkRentAdjustmentDialog extends StatefulWidget {
  final String title;
  final String description;

  const _BulkRentAdjustmentDialog({
    required this.title,
    required this.description,
  });

  @override
  State<_BulkRentAdjustmentDialog> createState() =>
      _BulkRentAdjustmentDialogState();
}

class _BulkRentAdjustmentDialogState extends State<_BulkRentAdjustmentDialog> {
  late final TextEditingController _amountController;

  DateTime _selectedDate = DateTime.now();

  RentAdjustmentType _adjustmentType =
      RentAdjustmentType.increase;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();

    super.dispose();
  }

  Future<void> _selectEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
    });
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid adjustment amount.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      _RentAdjustmentResult(
        amount: amount,
        adjustmentType: _adjustmentType,
        effectiveFrom: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease =
        _adjustmentType ==
            RentAdjustmentType.increase;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(widget.description),

            const SizedBox(height: 20),

            // ----------------------------------------------------------
            // ADJUSTMENT TYPE
            // ----------------------------------------------------------

            Text(
              'Adjustment',
              style: Theme
                  .of(context)
                  .textTheme
                  .labelLarge,
            ),

            const SizedBox(height: 8),

            SegmentedButton<RentAdjustmentType>(
              segments: const [
                ButtonSegment<RentAdjustmentType>(
                  value:
                  RentAdjustmentType.increase,
                  icon: Icon(
                    Icons.arrow_upward,
                  ),
                  label: Text(
                    'Increase',
                  ),
                ),
                ButtonSegment<RentAdjustmentType>(
                  value:
                  RentAdjustmentType.decrease,
                  icon: Icon(
                    Icons.arrow_downward,
                  ),
                  label: Text(
                    'Decrease',
                  ),
                ),
              ],
              selected: {
                _adjustmentType,
              },
              onSelectionChanged:
                  (selection) {
                setState(() {
                  _adjustmentType =
                      selection.first;
                });
              },
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------------
            // ADJUSTMENT AMOUNT
            // ----------------------------------------------------------

            TextField(
              controller: _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration:
              const InputDecoration(
                labelText:
                'Adjustment Amount',
                hintText:
                'Example: 1000',
                prefixText: '৳ ',
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isIncrease
                  ? 'This amount will be added to each '
                  'occupied unit\'s current rent.'
                  : 'This amount will be deducted from each '
                  'occupied unit\'s current rent.',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodySmall,
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // EFFECTIVE FROM
            // ----------------------------------------------------------

            InkWell(
              borderRadius:
              BorderRadius.circular(12),
              onTap: _selectEffectiveDate,
              child: InputDecorator(
                decoration:
                const InputDecoration(
                  labelText:
                  'Effective From',
                  border:
                  OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_outlined,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        _formatDate(
                          _selectedDate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // PREVIEW
            // ----------------------------------------------------------

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(12),
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius.circular(12),
                color: Theme
                    .of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIncrease
                        ? Icons.trending_up
                        : Icons.trending_down,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? 'Example: a unit with '
                          '৳12,000 rent will become '
                          '৳13,000 when the adjustment '
                          'is ৳1,000.'
                          : 'Example: a unit with '
                          '৳12,000 rent will become '
                          '৳11,000 when the adjustment '
                          'is ৳1,000.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Continue',
          ),
        ),
      ],
    );
  }
}

// ================================================================
// RENT ADJUSTMENT RESULT
// ================================================================

class _RentAdjustmentResult {
  final double amount;
  final RentAdjustmentType adjustmentType;
  final DateTime effectiveFrom;

  const _RentAdjustmentResult({
    required this.amount,
    required this.adjustmentType,
    required this.effectiveFrom,
  });
}

// ================================================================
// RENT SCOPE CARD
// ================================================================

class _RentScopeCard extends StatelessWidget {
  final int floorNumber;
  final String propertyName;

  final VoidCallback onUnitRent;
  final VoidCallback onFloorRent;
  final VoidCallback onPropertyRent;

  final bool enabled;

  const _RentScopeCard({
    required this.floorNumber,
    required this.propertyName,
    required this.onUnitRent,
    required this.onFloorRent,
    required this.onPropertyRent,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Change Rent',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleLarge,
            ),

            const SizedBox(height: 6),

            Text(
              'Choose where you want to apply the rent change.',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: Theme
                    .of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            _RentScopeTile(
              icon:
              Icons.home_work_outlined,
              title: 'Unit Rent',
              subtitle:
              'Set rent for this unit only.',
              onTap:
              enabled ? onUnitRent : null,
            ),

            const Divider(height: 1),

            _RentScopeTile(
              icon:
              Icons.layers_outlined,
              title: 'Floor Rent',
              subtitle:
              'Increase or decrease rent for occupied '
                  'units on Floor $floorNumber.',
              onTap:
              enabled ? onFloorRent : null,
            ),

            const Divider(height: 1),

            _RentScopeTile(
              icon:
              Icons.apartment_outlined,
              title: 'Property Rent',
              subtitle:
              'Increase or decrease rent for occupied '
                  'units in $propertyName.',
              onTap:
              enabled ? onPropertyRent : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// RENT SCOPE TILE
// ================================================================

class _RentScopeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _RentScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        vertical: 6,
      ),
      leading: CircleAvatar(
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }
}

// ================================================================
// UNIT HEADER
// ================================================================

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
        padding:
        const EdgeInsets.all(28),
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
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
            ),

            const SizedBox(height: 8),

            Text(
              unit.name
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? unit.name!
                  : 'Unit',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
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
                  .bodyLarge
                  ?.copyWith(
                color: Theme
                    .of(context)
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

// ================================================================
// CURRENT TENANT CARD
// ================================================================

class _CurrentTenantCard extends StatelessWidget {
  final List<Tenant> tenants;

  const _CurrentTenantCard({
    required this.tenants,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Current Tenant',
              style: Theme
                  .of(context)
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
                  final tenant =
                  tenants[index];

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
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Text(
                                  tenant.name,
                                  style: Theme
                                      .of(
                                    context,
                                  )
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (tenant.phone
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    tenant.phone,
                                    style: Theme
                                        .of(
                                      context,
                                    )
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

// ================================================================
// CURRENT RENT CARD
// ================================================================

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
          padding:
          const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Current Rent',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                hasActiveTenant
                    ? 'No rent rate has been configured for this unit.'
                    : 'No active tenant is assigned. The initial rent will be set when a tenant invitation is accepted.',
                style: Theme
                    .of(context)
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
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Rent',
                    style: Theme
                        .of(context)
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
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Effective from '
                  '${_formatDate(rentRate!.effectiveFrom)}',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width:
              double.infinity,
              child:
              OutlinedButton.icon(
                onPressed:
                hasActiveTenant
                    ? onChangeRent
                    : null,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Change Unit Rent',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SOURCE CHIP
// ================================================================

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

// ================================================================
// ERROR VIEW
// ================================================================

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
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              message,
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 16,
            ),
            FilledButton(
              onPressed: onRetry,
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HELPERS
// ================================================================

String _initials(String name) {
  final value = name.trim();

  if (value.isEmpty) {
    return '?';
  }

  final parts = value
      .split(RegExp(r'\s+'))
      .where(
        (part) => part.isNotEmpty,
  )
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

String _sourceLabel(RentRateSource source,) {
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