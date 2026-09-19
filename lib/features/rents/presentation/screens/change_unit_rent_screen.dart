import 'package:flutter/material.dart';
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

  const ChangeUnitRentScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<ChangeUnitRentScreen> createState() =>
      _ChangeUnitRentScreenState();
}

class _ChangeUnitRentScreenState
    extends ConsumerState<ChangeUnitRentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();

  DateTime _effectiveFrom = DateTime.now();

  bool _isSubmitting = false;

  Unit? _unit;
  Property? _property;
  Tenant? _tenant;

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
      final unit = await ref.read(
        unitByIdProvider(
          widget.unitId,
        ).future,
      );

      if (!mounted || unit == null) {
        return;
      }

      final property = await ref.read(
        propertyByIdProvider(
          unit.propertyId,
        ).future,
      );

      if (!mounted || property == null) {
        return;
      }

      final getActiveTenants = ref.read(
        getActiveTenantsByUnitIdProvider,
      );

      final tenants = await getActiveTenants(
        unit.id,
      );

      if (!mounted) {
        return;
      }

      final currentRent = await ref.read(
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
        _tenant = tenants.isEmpty ? null : tenants.first;

        if (currentRent != null) {
          _amountController.text = _formatAmount(
            currentRent.amount,
          );
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
      });
    }
  }

  Future<void> _selectEffectiveDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
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
      _showError(
        'Unit or property information is unavailable.',
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      _showError(
        'Enter a valid rent amount.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final controller = ref.read(
      rentRateControllerProvider.notifier,
    );

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
      final state = ref.read(
        rentRateControllerProvider,
      );

      final error = state.whenOrNull(
        error: (
            error,
            stackTrace,
            ) =>
            error.toString(),
      );

      _showError(
        error ?? 'Unable to change rent.',
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

    ref.invalidate(
      unitRentRateHistoryProvider(
        (
        unitId: unit.id,
        ownerId: property.ownerId,
        ),
      ),
    );

    if (context.mounted) {
      context.pop(result);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }

    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;
    final property = _property;
    final tenant = _tenant;

    if (unit == null || property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Change Rent',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Change Rent',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitNumber,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      property.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Floor ${unit.floorNumber}',
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 16,
                    ),
                    Text(
                      'Current Tenant',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      tenant?.name ?? 'Vacant',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            TextFormField(
              controller: _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'New Monthly Rent',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Enter the new rent amount.';
                }

                final amount = double.tryParse(text);

                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount.';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 20,
            ),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_today_outlined,
                ),
                title: const Text(
                  'Effective From',
                ),
                subtitle: Text(
                  _formatDate(
                    _effectiveFrom,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: _isSubmitting
                    ? null
                    : _selectEffectiveDate,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'The previous rent rate will end immediately before this effective date. The new rent rate will apply from this date.',
            ),

            const SizedBox(
              height: 28,
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
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