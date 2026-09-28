import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../providers/billing_rule_provider.dart';

class OwnerBillingSetupScreen extends ConsumerStatefulWidget {
  const OwnerBillingSetupScreen({
    super.key,
  });

  @override
  ConsumerState<OwnerBillingSetupScreen> createState() =>
      _OwnerBillingSetupScreenState();
}

class _OwnerBillingSetupScreenState
    extends ConsumerState<OwnerBillingSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  String? _selectedPropertyId;

  BillingChargeType _chargeType =
      BillingChargeType.water;

  BillingValueType _valueType =
      BillingValueType.fixed;

  DateTime _effectiveDate = DateTime.now();

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // ========================================================================
  // EFFECTIVE DATE
  // ========================================================================

  Future<void> _selectEffectiveDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveDate = selectedDate;
    });
  }

  // ========================================================================
  // SAVE
  // ========================================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPropertyId == null ||
        _selectedPropertyId!.trim().isEmpty) {
      _showMessage(
        'Please select a property.',
      );
      return;
    }

    final authState = ref.read(
      authStateProvider,
    );

    final firebaseUser = authState.value;

    if (firebaseUser == null) {
      _showMessage(
        'You are not signed in.',
      );
      return;
    }

    final ownerId = firebaseUser.uid.trim();

    if (ownerId.isEmpty) {
      _showMessage(
        'Unable to determine owner ID.',
      );
      return;
    }

    double? amount;

    if (_valueType == BillingValueType.fixed) {
      amount = double.tryParse(
        _amountController.text.trim(),
      );

      if (amount == null || amount < 0) {
        _showMessage(
          'Please enter a valid amount.',
        );
        return;
      }
    }

    final title = _titleController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final request = CreateBillingRuleRequest(
        ownerId: ownerId,
        propertyId: _selectedPropertyId!.trim(),

        scopeType: BillingScopeType.property,
        scopeId: _selectedPropertyId!.trim(),

        chargeType: _chargeType,
        valueType: _valueType,

        amount: amount,

        title: title.isEmpty
            ? null
            : title,

        effectiveFrom: _effectiveDate,

        effectiveTo: null,

        isActive: _isActive,
      );

      final createBillingRule =
      ref.read(
        createBillingRuleProvider,
      );

      final rule =
      await createBillingRule(
        request,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(
        propertyBillingRulesProvider(
          (
          ownerId: ownerId,
          propertyId:
          _selectedPropertyId!.trim(),
          ),
        ),
      );

      _showMessage(
        'Billing rule created successfully.',
      );

      debugPrint(
        'BILLING: Rule created successfully.',
      );

      debugPrint(
        'BILLING: Rule ID = ${rule.id}',
      );

      debugPrint(
        'BILLING: Property ID = ${rule.propertyId}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'BILLING: Failed to create billing rule.',
      );

      debugPrint(
        'BILLING ERROR: $error',
      );

      debugPrint(
        'BILLING STACK: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========================================================================
  // ERROR MESSAGE
  // ========================================================================

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ========================================================================
  // SNACKBAR
  // ========================================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ========================================================================
  // DATE FORMAT
  // ========================================================================

  String _formatDate(DateTime date) {
    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    final year = date.year.toString();

    return '$day/$month/$year';
  }

  // ========================================================================
  // CHARGE TYPE LABEL
  // ========================================================================

  String _chargeTypeLabel(
      BillingChargeType type,
      ) {
    switch (type) {
      case BillingChargeType.water:
        return 'Water';

      case BillingChargeType.gas:
        return 'Gas';

      case BillingChargeType.garbage:
        return 'Garbage';

      case BillingChargeType.serviceCharge:
        return 'Service Charge';

      case BillingChargeType.electricity:
        return 'Electricity';

      case BillingChargeType.other:
        return 'Other';
    }
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final propertiesAsync = ref.watch(
      currentOwnerPropertiesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing Setup',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ==================================================================
            // HEADER
            // ==================================================================

            Text(
              'Create Billing Rule',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Configure a recurring billing rule for your property.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // PROPERTY
            // ==================================================================

            Text(
              'Property',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            propertiesAsync.when(
              loading: () {
                return const InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Property',
                    prefixIcon: Icon(
                      Icons.apartment_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading properties...',
                      ),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) {
                return InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Property',
                    prefixIcon: Icon(
                      Icons.apartment_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Unable to load properties.',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retry',
                        onPressed: () {
                          ref.invalidate(
                            currentOwnerPropertiesProvider,
                          );
                        },
                        icon: const Icon(
                          Icons.refresh,
                        ),
                      ),
                    ],
                  ),
                );
              },
              data: (properties) {
                if (properties.isEmpty) {
                  return const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Property',
                      prefixIcon: Icon(
                        Icons.apartment_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      'No property found. Add a property first.',
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: properties.any(
                        (property) =>
                    property.id ==
                        _selectedPropertyId,
                  )
                      ? _selectedPropertyId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Select property',
                    prefixIcon: Icon(
                      Icons.apartment_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final property in properties)
                      DropdownMenuItem<String>(
                        value: property.id,
                        child: Text(
                          property.name,
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPropertyId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please select a property.';
                    }

                    return null;
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // CHARGE TYPE
            // ==================================================================

            Text(
              'Charge Type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<BillingChargeType>(
              initialValue: _chargeType,
              decoration: const InputDecoration(
                labelText: 'Bill type',
                prefixIcon: Icon(
                  Icons.receipt_long_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: BillingChargeType.values
                  .map(
                    (type) =>
                    DropdownMenuItem<
                        BillingChargeType>(
                      value: type,
                      child: Text(
                        _chargeTypeLabel(type),
                      ),
                    ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _chargeType = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // TITLE
            // ==================================================================

            Text(
              'Title',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _titleController,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Optional title',
                hintText:
                'Example: Monthly water charge',
                prefixIcon: Icon(
                  Icons.title_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_chargeType ==
                    BillingChargeType.other &&
                    (value == null ||
                        value.trim().isEmpty)) {
                  return 'Please enter a title for this charge.';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // AMOUNT TYPE
            // ==================================================================

            Text(
              'Amount Type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            SegmentedButton<BillingValueType>(
              segments: const [
                ButtonSegment<BillingValueType>(
                  value: BillingValueType.fixed,
                  icon: Icon(
                    Icons.lock_outline,
                  ),
                  label: Text('Fixed'),
                ),
                ButtonSegment<BillingValueType>(
                  value: BillingValueType.variable,
                  icon: Icon(
                    Icons.tune_outlined,
                  ),
                  label: Text('Variable'),
                ),
              ],
              selected: {_valueType},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }

                setState(() {
                  _valueType =
                      selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // AMOUNT
            // ==================================================================

            Text(
              'Amount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _amountController,
              enabled:
              _valueType ==
                  BillingValueType.fixed,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '৳ ',
                prefixIcon: Icon(
                  Icons.payments_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_valueType ==
                    BillingValueType.variable) {
                  return null;
                }

                final text =
                    value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Please enter an amount.';
                }

                final amount =
                double.tryParse(text);

                if (amount == null) {
                  return 'Enter a valid amount.';
                }

                if (amount < 0) {
                  return 'Amount cannot be negative.';
                }

                return null;
              },
            ),

            if (_valueType ==
                BillingValueType.variable) ...[
              const SizedBox(height: 8),
              Text(
                'Variable bills will use the actual amount when the monthly bill is generated.',
                style:
                theme.textTheme.bodySmall?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ==================================================================
            // SCOPE
            // ==================================================================

            Text(
              'Billing Scope',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'Apply rule to',
                prefixIcon: Icon(
                  Icons.account_tree_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              child: Text(
                'Entire Property',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Property-level billing is currently configured. '
                  'Floor, unit and tenant-specific rules will be connected '
                  'when their selectors are added.',
              style:
              theme.textTheme.bodySmall?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // EFFECTIVE DATE
            // ==================================================================

            Text(
              'Effective Date',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            InkWell(
              borderRadius:
              BorderRadius.circular(12),
              onTap: _selectEffectiveDate,
              child: InputDecorator(
                decoration:
                const InputDecoration(
                  labelText:
                  'Rule starts from',
                  prefixIcon: Icon(
                    Icons.calendar_month_outlined,
                  ),
                  border:
                  OutlineInputBorder(),
                ),
                child: Text(
                  _formatDate(
                    _effectiveDate,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================================
            // ACTIVE
            // ==================================================================

            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                title: const Text(
                  'Active billing rule',
                ),
                subtitle: const Text(
                  'Inactive rules will not be used for new monthly bills.',
                ),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) {
                  setState(() {
                    _isActive =
                        value;
                  });
                },
              ),
            ),

            const SizedBox(height: 32),

            // ==================================================================
            // SAVE
            // ==================================================================

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : 'Save Billing Rule',
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'The rule will be used by automatic monthly bill generation.',
              textAlign: TextAlign.center,
              style:
              theme.textTheme.bodySmall?.copyWith(
                color: theme
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