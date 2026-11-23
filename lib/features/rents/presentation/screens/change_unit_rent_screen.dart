// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';
import '../widgets/rent_ui_helpers.dart';

class ChangeUnitRentScreen extends ConsumerStatefulWidget {
  final String unitId;

  const ChangeUnitRentScreen({super.key, required this.unitId});

  @override
  ConsumerState<ChangeUnitRentScreen> createState() =>
      _ChangeUnitRentScreenState();
}

class _ChangeUnitRentScreenState extends ConsumerState<ChangeUnitRentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  DateTime _effectiveFrom = DateTime.now();

  bool _isSubmitting = false;
  bool _isLoading = true;

  Unit? _unit;
  Property? _property;
  Tenant? _tenant;
  double? _currentRentAmount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final unit = await ref.read(unitByIdProvider(widget.unitId).future);
      if (!mounted || unit == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final property = await ref.read(
        propertyByIdProvider(unit.propertyId).future,
      );
      if (!mounted || property == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Fetch active tenants and current rent rate in parallel.
      final results = await Future.wait<dynamic>([
        ref.read(getActiveTenantsByUnitIdProvider)(unit.id),
        ref.read(
          currentRentRateProvider((
          unitId: unit.id,
          ownerId: property.ownerId,
          )).future,
        ),
      ]);

      var tenants = results[0] as List<Tenant>;
      final currentRent = results[1] as RentRate?;

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
        _tenant = tenants.isEmpty ? null : tenants.first;
        _currentRentAmount = currentRent?.amount;
        _isLoading = false;

        if (currentRent != null) {
          _amountController.text = formatRentAmount(currentRent.amount);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _unit = null;
        _property = null;
        _tenant = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectEffectiveDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _effectiveFrom = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
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

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      GrihoFeedback.showError(context, 'Please enter a valid rent amount.');
      return;
    }

    // Skip Firestore write if amount is identical to current rent rate.
    if (_currentRentAmount != null &&
        (amount - _currentRentAmount!).abs() < 0.01) {
      GrihoFeedback.showInfo(
        context,
        'New rent amount is the same as the current rate.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final controller = ref.read(rentRateControllerProvider.notifier);
    final result = await controller.changeUnitRent(
      unitId: unit.id,
      ownerId: property.ownerId,
      amount: amount,
      effectiveFrom: _effectiveFrom,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (result == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(error: (e, _) => e.toString());
      GrihoFeedback.showError(
        context,
        error?.replaceFirst('Bad state: ', '') ?? 'Unable to update rent rate.',
      );
      return;
    }

    ref.invalidate(
      currentRentRateProvider((unitId: unit.id, ownerId: property.ownerId)),
    );
    ref.invalidate(
      unitRentRateHistoryProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    GrihoFeedback.showSuccess(context, 'Rent rate updated successfully.');
    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Update Rent')),
        body: const GrihoLoadingView(message: 'Loading unit rent...'),
      );
    }

    final unit = _unit;
    final property = _property;
    final tenant = _tenant;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Update Rent')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load unit',
              subtitle: 'Unit or property information could not be loaded.',
              actionLabel: 'Retry',
              onAction: _loadData,
            ),
          ),
        ),
      );
    }

    final isOccupied = tenant != null || unit.status == UnitStatus.occupied;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Update Rent Rate')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Resident',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tenant?.name ?? 'No active tenant',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Current Monthly Rent',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentRentAmount != null
                                  ? '৳ ${formatRentAmount(_currentRentAmount)}'
                                  : 'Not set',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GrihoSectionCard(
                title: 'New Rent Configuration',
                subtitle:
                'Specify the updated recurring monthly rate for this unit.',
                icon: Iconsax.wallet_3,
                children: [
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'New Monthly Rent',
                      hintText: 'e.g. 15000',
                      prefixText: '৳ ',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Please enter the new rent amount.';
                      }
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount greater than zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isSubmitting ? null : _selectEffectiveDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Effective Date',
                        prefixIcon: Icon(
                          Iconsax.calendar_1,
                          color: GrihoColors.emerald,
                          size: 20,
                        ),
                        suffixIcon: Icon(Iconsax.arrow_right_3, size: 16),
                      ),
                      child: Text(
                        formatRentDate(_effectiveFrom),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Iconsax.info_circle,
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The ongoing rate snapshot will end immediately before the selected effective date. Newly generated monthly bills following this date will reflect the revised amount.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              GrihoPrimaryButton(
                label: _isSubmitting ? 'Saving Rate...' : 'Confirm Rate Update',
                icon: Iconsax.tick_circle,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
