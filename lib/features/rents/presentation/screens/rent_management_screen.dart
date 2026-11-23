// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../tenants/presentation/widgets/tenant_ui_helpers.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';
import '../widgets/rent_ui_helpers.dart';

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

      final rateArgs = (unitId: unit.id, ownerId: property.ownerId);
      if (forceRefresh) {
        ref.invalidate(currentRentRateProvider(rateArgs));
      }

      // Fetch active tenants and current rent rate concurrently.
      final results = await Future.wait<dynamic>([
        ref.read(getActiveTenantsByUnitIdProvider)(unit.id),
        ref.read(currentRentRateProvider(rateArgs).future),
      ]);

      var tenants = results[0] as List<Tenant>;
      final rentRate = results[1] as RentRate?;

      if (tenants.isEmpty && unit.status == UnitStatus.occupied) {
        final snap = await FirebaseFirestore.instance
            .collection('tenants')
            .where('unitId', isEqualTo: unit.id)
            .where('status', isEqualTo: 'active')
            .limit(10)
            .get();

        tenants = snap.docs.map(TenantModel.fromFirestore).toList();
      }

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
    await _loadData(forceRefresh: true);
  }

  Future<void> _openRentChange() async {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    final updatedRate = await context.push<RentRate>(
      RouteNames.changeUnitRent.replaceFirst(':unitId', unit.id),
    );

    // Only update/refresh if the user actually saved a new rent rate.
    if (!mounted || updatedRate == null) {
      return;
    }

    setState(() => _currentRentRate = updatedRate);
  }

  Future<void> _openFloorRentChange() async {
    final unit = _unit;
    if (unit == null) {
      return;
    }

    final result = await _showBulkRentAdjustmentDialog(
      title: 'Adjust Floor Rent',
      description:
          'This will adjust the recurring rent for all units located on Floor ${unit.floorNumber}.',
    );

    if (!mounted || result == null) {
      return;
    }

    await _applyBulkRentChange(
      isFloorScope: true,
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
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
          'This will adjust the recurring rent for all units throughout "${property.name}".',
    );

    if (!mounted || result == null) {
      return;
    }

    await _applyBulkRentChange(
      isFloorScope: false,
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
    );
  }

  Future<void> _applyBulkRentChange({
    required bool isFloorScope,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    final unit = _unit;
    final property = _property;

    if (unit == null || property == null || _isChangingBulkRent) {
      return;
    }

    setState(() => _isChangingBulkRent = true);

    final controller = ref.read(rentRateControllerProvider.notifier);

    final result = isFloorScope
        ? await controller.changeFloorRent(
            propertyId: property.id,
            floorNumber: unit.floorNumber,
            ownerId: property.ownerId,
            amount: amount,
            adjustmentType: adjustmentType,
            effectiveFrom: effectiveFrom,
          )
        : await controller.changePropertyRent(
            propertyId: property.id,
            ownerId: property.ownerId,
            amount: amount,
            adjustmentType: adjustmentType,
            effectiveFrom: effectiveFrom,
          );

    if (!mounted) {
      return;
    }

    setState(() => _isChangingBulkRent = false);

    if (result == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(error: (e, _) => e.toString());

      GrihoFeedback.showError(
        context,
        error?.replaceFirst('Bad state: ', '') ??
            (isFloorScope
                ? 'Unable to adjust floor rent.'
                : 'Unable to adjust property rent.'),
      );
      return;
    }

    for (final rate in result) {
      ref.invalidate(
        currentRentRateProvider((unitId: rate.unitId, ownerId: rate.ownerId)),
      );
      ref.invalidate(
        unitRentRateHistoryProvider((
          unitId: rate.unitId,
          ownerId: rate.ownerId,
        )),
      );
    }

    final updatedThisUnit = result
        .where((r) => r.unitId == unit.id)
        .firstOrNull;
    if (updatedThisUnit != null && !effectiveFrom.isAfter(DateTime.now())) {
      setState(() => _currentRentRate = updatedThisUnit);
    } else {
      await _loadData(forceRefresh: true);
    }

    if (!mounted) {
      return;
    }

    final scopeLabel = isFloorScope ? 'Floor' : 'Property';
    final action = adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    GrihoFeedback.showSuccess(
      context,
      '$scopeLabel rent$action by ৳${formatRentAmount(amount)} for${result.length} unit(s).',
    );
  }

  Future<_RentAdjustmentResult?> _showBulkRentAdjustmentDialog({
    required String title,
    required String description,
  }) {
    return showDialog<_RentAdjustmentResult>(
      context: context,
      builder: (_) =>
          _BulkRentAdjustmentDialog(title: title, description: description),
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
        body: const GrihoLoadingView(message: 'Loading rent details...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load rent details',
              subtitle: _errorMessage!,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
        ),
      );
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Management')),
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

    final isOccupied =
        _activeTenants.isNotEmpty || unit.status == UnitStatus.occupied;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Rent Management')),
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
                const SizedBox(height: 20),
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
                  GrihoPrimaryButton(
                    label: 'Monthly Rent Invoices',
                    icon: Iconsax.receipt_item,
                    onPressed: _isChangingBulkRent ? null : _openMonthlyRent,
                  ),
                  const SizedBox(height: 12),
                ],
                GrihoSecondaryButton(
                  label: 'Rate Adjustment History',
                  icon: Iconsax.clock,
                  onPressed: _isChangingBulkRent ? null : _openRentHistory,
                ),
              ],
            ),
          ),
          if (_isChangingBulkRent)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: GrihoLoadingView(
                        message: 'Updating rent rates...',
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
              Iconsax.home_2,
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
          RentOccupancyChip(isOccupied: isOccupied),
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

    return GrihoSectionCard(
      title: 'Active Resident',
      icon: Iconsax.user,
      children: [
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
                        tenantInitials(tenant.name),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
      return GrihoSectionCard(
        title: 'Monthly Rent Rate',
        icon: Iconsax.wallet_3,
        children: [
          Text(
            hasActiveTenant
                ? 'No rent rate is currently active for this unit.'
                : 'Rent will be established once a tenant invitation is formally accepted.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
              RentSourceChip(source: rentRate!.source),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '৳ ${formatRentAmount(rentRate!.amount)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective since ${formatRentDate(rentRate!.effectiveFrom)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          GrihoSecondaryButton(
            label: 'Update Unit Rent',
            icon: Iconsax.edit_2,
            onPressed: hasActiveTenant ? onChangeRent : null,
          ),
        ],
      ),
    );
  }
}

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
    return GrihoSectionCard(
      title: 'Adjust Rent Across Scopes',
      subtitle:
          'Select the target perimeter to adjust recurring rent agreements.',
      icon: Iconsax.setting_4,
      children: [
        _ScopeTile(
          icon: Iconsax.home_2,
          title: 'Individual Unit',
          subtitle: 'Apply rent modification solely to this unit.',
          onTap: enabled ? onUnitRent : null,
        ),
        const Divider(height: 1, indent: 56),
        _ScopeTile(
          icon: Iconsax.layer,
          title: 'Floor $floorNumber Units',
          subtitle: 'Adjust rent for all units on this floor.',
          onTap: enabled ? onFloorRent : null,
        ),
        const Divider(height: 1, indent: 56),
        _ScopeTile(
          icon: Iconsax.buildings_2,
          title: 'Entire Property',
          subtitle: 'Adjust rent for all units across $propertyName.',
          onTap: enabled ? onPropertyRent : null,
        ),
      ],
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
        child: Icon(icon, size: 19, color: theme.colorScheme.primary),
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
      trailing: const Icon(Iconsax.arrow_right_3, size: 16),
      onTap: onTap,
    );
  }
}

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
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  RentAdjustmentType _adjustmentType = RentAdjustmentType.increase;

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
      GrihoFeedback.showError(
        context,
        'Please enter a valid adjustment amount.',
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
            const SizedBox(height: 18),
            SegmentedButton<RentAdjustmentType>(
              segments: const [
                ButtonSegment(
                  value: RentAdjustmentType.increase,
                  icon: Icon(Iconsax.trend_up, size: 16),
                  label: Text('Increase'),
                ),
                ButtonSegment(
                  value: RentAdjustmentType.decrease,
                  icon: Icon(Iconsax.trend_down, size: 16),
                  label: Text('Decrease'),
                ),
              ],
              selected: {_adjustmentType},
              onSelectionChanged: (selection) =>
                  setState(() => _adjustmentType = selection.first),
            ),
            const SizedBox(height: 16),
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
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectEffectiveDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Effective Date',
                  prefixIcon: Icon(
                    Iconsax.calendar_1,
                    color: GrihoColors.emerald,
                    size: 20,
                  ),
                ),
                child: Text(formatRentDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIncrease ? Iconsax.trend_up : Iconsax.trend_down,
                    size: 18,
                    color: isIncrease
                        ? GrihoColors.emerald
                        : GrihoColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? 'Example: A unit renting at ৳12,000 will become ৳13,000 with a ৳1,000 increase.'
                          : 'Example: A unit renting at ৳12,000 will become ৳11,000 with a ৳1,000 reduction.',
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
          onPressed: () => Navigator.of(context).pop(),
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
