import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../providers/rent_rate_provider.dart';

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
        return;
      }

      final property = await ref.read(
        propertyByIdProvider(unit.propertyId).future,
      );

      if (!mounted || property == null) {
        return;
      }

      final getActiveTenants = ref.read(getActiveTenantsByUnitIdProvider);
      final tenants = await getActiveTenants(unit.id);

      if (!mounted) {
        return;
      }

      final currentRent = await ref.read(
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
        _tenant = tenants.isEmpty ? null : tenants.first;
        _currentRentAmount = currentRent?.amount;
        _isLoading = false;

        if (currentRent != null) {
          _amountController.text = _formatAmount(currentRent.amount);
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
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final unit = _unit;
    final property = _property;

    if (unit == null || property == null) {
      _showError('Unit or property information is unavailable.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid rent amount.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

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

    setState(() {
      _isSubmitting = false;
    });

    if (result == null) {
      final state = ref.read(rentRateControllerProvider);
      final error = state.whenOrNull(
        error: (error, stackTrace) => error.toString(),
      );

      _showError(error ?? 'Unable to update rent rate.');
      return;
    }

    ref.invalidate(
      currentRentRateProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    ref.invalidate(
      unitRentRateHistoryProvider((unitId: unit.id, ownerId: property.ownerId)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rent rate updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (context.mounted) {
      context.pop(result);
    }
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

  String _formatAmount(num? amount) {
    if (amount == null) {
      return '0';
    }
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Update Rent')),
        body: const Center(child: CircularProgressIndicator()),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load unit or property information.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadData, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final isOccupied = tenant != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Update Rent Rate',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // 1. Unit & Property Overview Card
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                                  ? '৳ ${_formatAmount(_currentRentAmount)}'
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

              // 2. New Rent Input Section
              Container(
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
                          Icons.payments_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'New Rent Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Specify the updated recurring monthly rate for this unit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        border: OutlineInputBorder(),
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
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          suffixIcon: Icon(Icons.chevron_right),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _formatDate(_effectiveFrom),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Informational Policy Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
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

              const SizedBox(height: 32),

              // 4. Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isSubmitting ? 'Saving Rate...' : 'Confirm Rate Update',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
