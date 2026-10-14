import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const RentManagementScreen({super.key, required this.unitId});

  @override
  ConsumerState<RentManagementScreen> createState() =>
      _RentManagementScreenState();
}

class _RentManagementScreenState extends ConsumerState<RentManagementScreen> {
  Unit? _unit;
  Property? _property;
  List<Tenant> _activeTenants = const [];
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

      final getActiveTenants = ref.read(getActiveTenantsByUnitIdProvider);
      final tenants = await getActiveTenants(unit.id);

      final rentRate = await ref.read(
        currentRentRateProvider((
          unitId: unit.id,
          ownerId: property.ownerId,
        )).future,
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
      currentRentRateProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    await _loadData();
  }

  void _openRentChange() {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    context
        .push(RouteNames.changeUnitRent.replaceFirst(':unitId', unit.id))
        .then((_) {
          if (mounted) {
            _refresh();
          }
        });
  }

  Future<void> _openFloorRentChange() async {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    final result = await _showBulkRentAdjustmentDialog(
      title: 'Adjust Floor Rent',
      description:
          'This will adjust the recurring rent for all occupied units located on Floor ${unit.floorNumber}.',
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

    final controller = ref.read(rentRateControllerProvider.notifier);

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
          .whenOrNull(error: (error, stackTrace) => error.toString());

      _showError(error ?? 'Unable to adjust floor rent.');
      return;
    }

    ref.invalidate(
      currentRentRateProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    await _loadData();

    if (!mounted) {
      return;
    }

    final action = adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    _showSuccess(
      'Floor rent $action by ৳${_formatAmount(amount)} for ${result.length} occupied unit(s).',
    );
  }

  Future<void> _openPropertyRentChange() async {
    final property = _property;
    if (property == null) {
      return;
    }

    final result = await _showBulkRentAdjustmentDialog(
      title: 'Adjust Property Rent',
      description:
          'This will adjust the recurring rent for all occupied units throughout "${property.name}".',
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

    final controller = ref.read(rentRateControllerProvider.notifier);

    final result = await controller.changePropertyRent(
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
          .whenOrNull(error: (error, stackTrace) => error.toString());

      _showError(error ?? 'Unable to adjust property rent.');
      return;
    }

    ref.invalidate(
      currentRentRateProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    await _loadData();

    if (!mounted) {
      return;
    }

    final action = adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    _showSuccess(
      'Property rent $action by ৳${_formatAmount(amount)} for ${result.length} occupied unit(s).',
    );
  }

  Future<_RentAdjustmentResult?> _showBulkRentAdjustmentDialog({
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openRentHistory() {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    context.push(
      RouteNames.unitRentRateHistory.replaceFirst(':unitId', unit.id),
    );
  }

  void _openMonthlyRent() {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    context.push(RouteNames.unitMonthlyRent.replaceFirst(':unitId', unit.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Management')),
        body: _ErrorView(message: _errorMessage!, onRetry: _loadData),
      );
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Management')),
        body: const Center(child: Text('Required information was not found.')),
      );
    }

    final isOccupied = _activeTenants.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Rent Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _UnitHeaderCard(
                  unit: unit,
                  property: property,
                  isOccupied: isOccupied,
                ),

                const SizedBox(height: 16),

                _CurrentTenantCard(tenants: _activeTenants),

                const SizedBox(height: 16),

                _CurrentRentCard(
                  rentRate: _currentRentRate,
                  hasActiveTenant: isOccupied,
                  onChangeRent: _openRentChange,
                ),

                const SizedBox(height: 24),

                // Fixed: _RentScopeCard now uses Material
                _RentScopeCard(
                  floorNumber: unit.floorNumber,
                  propertyName: property.name,
                  onUnitRent: _openRentChange,
                  onFloorRent: _openFloorRentChange,
                  onPropertyRent: _openPropertyRentChange,
                  enabled: !_isChangingBulkRent,
                ),

                const SizedBox(height: 24),

                if (_currentRentRate != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isChangingBulkRent ? null : _openMonthlyRent,
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: const Text(
                        'Monthly Rent Invoices',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isChangingBulkRent ? null : _openRentHistory,
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: const Text(
                      'Rate Adjustment History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isChangingBulkRent)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Updating rent rates...',
                            style: TextStyle(fontWeight: FontWeight.bold),
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

class _UnitHeaderCard extends StatelessWidget {
  final Unit unit;
  final Property property;
  final bool isOccupied;

  const _UnitHeaderCard({
    required this.unit,
    required this.property,
    required this.isOccupied,
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
              Icons.door_front_door_outlined,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOccupied
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.blue.withValues(alpha: 0.12),
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
          ),
        ],
      ),
    );
  }
}

class _CurrentTenantCard extends StatelessWidget {
  final List<Tenant> tenants;

  const _CurrentTenantCard({required this.tenants});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Resident',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tenants.isEmpty)
            Text(
              'No resident currently occupies this unit.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...List.generate(tenants.length, (index) {
              final tenant = tenants[index];
              return Column(
                children: [
                  if (index > 0) const Divider(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          _initials(tenant.name),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenant.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (tenant.phone.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                tenant.phone,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
        ],
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
    final theme = Theme.of(context);

    if (rentRate == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Rent Rate',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveTenant
                  ? 'No rent rate is currently active for this unit.'
                  : 'Rent will be established once a tenant invitation is formally accepted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

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
                'Current Rent Rate',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              _SourceChip(source: rentRate!.source),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '৳ ${_formatAmount(rentRate!.amount)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective since ${_formatDate(rentRate!.effectiveFrom)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: hasActiveTenant ? onChangeRent : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Update Unit Rent'),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 4. RENT SCOPE SELECTOR CARD (Fixed with Material)
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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    Icons.tune_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Adjust Rent Across Scopes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select the target perimeter to adjust recurring rent agreements.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _ScopeTile(
              icon: Icons.door_front_door_outlined,
              title: 'Individual Unit',
              subtitle: 'Apply rent modification solely to this unit.',
              onTap: enabled ? onUnitRent : null,
            ),
            const Divider(height: 1, indent: 56),
            _ScopeTile(
              icon: Icons.layers_outlined,
              title: 'Floor $floorNumber Units',
              subtitle: 'Adjust rent for all active units on this floor.',
              onTap: enabled ? onFloorRent : null,
            ),
            const Divider(height: 1, indent: 56),
            _ScopeTile(
              icon: Icons.apartment_rounded,
              title: 'Entire Property',
              subtitle:
                  'Adjust rent for all active units across $propertyName.',
              onTap: enabled ? onPropertyRent : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// ================================================================
// BULK RENT ADJUSTMENT MODAL
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
  RentAdjustmentType _adjustmentType = RentAdjustmentType.increase;

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
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid adjustment amount.'),
          behavior: SnackBarBehavior.floating,
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
    final theme = Theme.of(context);
    final isIncrease = _adjustmentType == RentAdjustmentType.increase;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 20),
            SegmentedButton<RentAdjustmentType>(
              segments: const [
                ButtonSegment(
                  value: RentAdjustmentType.increase,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Increase'),
                ),
                ButtonSegment(
                  value: RentAdjustmentType.decrease,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Decrease'),
                ),
              ],
              selected: {_adjustmentType},
              onSelectionChanged: (selection) {
                setState(() {
                  _adjustmentType = selection.first;
                });
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Adjustment Amount',
                hintText: 'e.g. 1000',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectEffectiveDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Effective Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_formatDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIncrease ? Icons.trending_up : Icons.trending_down,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? 'Example: An apartment renting at ৳12,000 will become ৳13,000 with a ৳1,000 increase.'
                          : 'Example: An apartment renting at ৳12,000 will become ৳11,000 with a ৳1,000 reduction.',
                      style: theme.textTheme.bodySmall,
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
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply Changes')),
      ],
    );
  }
}

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

class _SourceChip extends StatelessWidget {
  final RentRateSource source;

  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _sourceLabel(source),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

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
  final date = dateTime.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _sourceLabel(RentRateSource source) {
  switch (source) {
    case RentRateSource.initial:
      return 'Initial Lease';
    case RentRateSource.property:
      return 'Property Scope';
    case RentRateSource.floor:
      return 'Floor Scope';
    case RentRateSource.unit:
      return 'Unit Scope';
  }
}
