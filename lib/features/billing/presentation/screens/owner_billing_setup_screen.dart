import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../providers/billing_rule_provider.dart';

class OwnerBillingSetupScreen extends ConsumerStatefulWidget {
  const OwnerBillingSetupScreen({super.key});

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

  BillingScopeType _scopeType = BillingScopeType.property;
  String? _selectedScopeId;

  BillingChargeType _chargeType = BillingChargeType.water;

  BillingValueType _valueType = BillingValueType.fixed;

  // Required.
  DateTime? _effectiveMonth;

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // ========================================================================
  // EFFECTIVE MONTH
  // ========================================================================

  Future<void> _selectEffectiveMonth() async {
    final now = DateTime.now();

    final initialDate = _effectiveMonth ?? DateTime(now.year, now.month, 1);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select effective month',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final normalizedMonth = DateTime(selectedDate.year, selectedDate.month, 1);

    setState(() {
      _effectiveMonth = normalizedMonth;
    });
  }

  // ========================================================================
  // SCOPE
  // ========================================================================

  String _scopeTypeLabel(BillingScopeType type) {
    switch (type) {
      case BillingScopeType.property:
        return 'Entire Property';

      case BillingScopeType.floor:
        return 'Specific Floor';

      case BillingScopeType.unit:
        return 'Specific Unit';

      case BillingScopeType.tenant:
        return 'Specific Tenant';
    }
  }

  IconData _scopeTypeIcon(BillingScopeType type) {
    switch (type) {
      case BillingScopeType.property:
        return Icons.apartment_outlined;

      case BillingScopeType.floor:
        return Icons.layers_outlined;

      case BillingScopeType.unit:
        return Icons.door_front_door_outlined;

      case BillingScopeType.tenant:
        return Icons.person_outline;
    }
  }

  void _changeScopeType(BillingScopeType? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _scopeType = value;

      _selectedScopeId = value == BillingScopeType.property
          ? _selectedPropertyId
          : null;
    });
  }

  // ========================================================================
  // FLOOR LIST
  // ========================================================================

  List<int> _getFloorNumbers(List<Unit> units) {
    final floors = <int>{};

    for (final unit in units) {
      floors.add(unit.floorNumber);
    }

    final result = floors.toList()
      ..sort();

    return result;
  }

  String _floorLabel(int floorNumber) {
    if (floorNumber == 0) {
      return 'Ground Floor';
    }

    if (floorNumber == 1) {
      return '1st Floor';
    }

    if (floorNumber == 2) {
      return '2nd Floor';
    }

    if (floorNumber == 3) {
      return '3rd Floor';
    }

    return '$floorNumber Floor';
  }

  // ========================================================================
  // UNIT LABEL
  // ========================================================================

  String _unitLabel(Unit unit) {
    final unitNumber = unit.unitNumber.trim();

    if (unit.name != null && unit.name!.trim().isNotEmpty) {
      return '${unit.name!.trim()} • Unit $unitNumber';
    }

    return 'Unit $unitNumber';
  }

  // ========================================================================
  // TENANT LABEL
  // ========================================================================

  String _tenantLabel(Tenant tenant) {
    final name = tenant.name.trim();

    if (tenant.phone
        .trim()
        .isNotEmpty) {
      return '$name • ${tenant.phone.trim()}';
    }

    return name;
  }

  // ========================================================================
  // SAVE
  // ========================================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPropertyId == null || _selectedPropertyId!.trim().isEmpty) {
      _showMessage('Please select a property.');
      return;
    }

    if (_selectedScopeId == null || _selectedScopeId!.trim().isEmpty) {
      _showMessage('Please select a billing scope.');
      return;
    }

    if (_effectiveMonth == null) {
      _showMessage('Please select an effective month.');
      return;
    }

    final authState = ref.read(authStateProvider);

    final firebaseUser = authState.value;

    if (firebaseUser == null) {
      _showMessage('You are not signed in.');
      return;
    }

    final ownerId = firebaseUser.uid.trim();

    if (ownerId.isEmpty) {
      _showMessage('Unable to determine owner ID.');
      return;
    }

    double? amount;

    if (_valueType == BillingValueType.fixed) {
      amount = double.tryParse(_amountController.text.trim());

      if (amount == null || amount < 0) {
        _showMessage('Please enter a valid amount.');
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

        scopeType: _scopeType,
        scopeId: _selectedScopeId!.trim(),

        chargeType: _chargeType,
        valueType: _valueType,

        amount: amount,

        title: title.isEmpty ? null : title,

        // Effective Month is stored as
        // the first day of the selected month.
        effectiveFrom: _effectiveMonth!,

        effectiveTo: null,

        isActive: _isActive,
      );

      final createBillingRule = ref.read(createBillingRuleProvider);

      final rule = await createBillingRule(request);

      if (!mounted) {
        return;
      }

      ref.invalidate(
        propertyBillingRulesProvider((
        ownerId: ownerId,
        propertyId: _selectedPropertyId!.trim(),
        )),
      );

      _showMessage('Billing rule created successfully.');

      debugPrint('BILLING: Rule created successfully.');

      debugPrint('BILLING: Rule ID = ${rule.id}');

      debugPrint('BILLING: Property ID = ${rule.propertyId}');

      debugPrint('BILLING: Scope Type = ${rule.scopeType.name}');

      debugPrint('BILLING: Scope ID = ${rule.scopeId}');

      debugPrint(
        'BILLING: Effective Month = '
            '${rule.effectiveFrom.year}-'
            '${rule.effectiveFrom.month}',
      );

      // Return the created rule to the previous screen.
      if (context.mounted) {
        Navigator.of(context).pop(rule);
      }
    } catch (error, stackTrace) {
      debugPrint('BILLING: Failed to create billing rule.');

      debugPrint('BILLING ERROR: $error');

      debugPrint('BILLING STACK: $stackTrace');

      if (!mounted) {
        return;
      }

      _showMessage(_cleanErrorMessage(error));
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
      return message.substring('Exception: '.length);
    }

    return message;
  }

  // ========================================================================
  // SNACKBAR
  // ========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ========================================================================
  // DATE FORMAT
  // ========================================================================

  String _formatMonth(DateTime date) {
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

    return '${months[date.month - 1]} ${date.year}';
  }

  // ========================================================================
  // CHARGE TYPE LABEL
  // ========================================================================

  String _chargeTypeLabel(BillingChargeType type) {
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

    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ================================================================
            // HEADER
            // ================================================================
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

            // ================================================================
            // PROPERTY
            // ================================================================
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
                    prefixIcon: Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Loading properties...'),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) {
                return InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Property',
                    prefixIcon: Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Unable to load properties.')),
                      IconButton(
                        tooltip: 'Retry',
                        onPressed: () {
                          ref.invalidate(currentOwnerPropertiesProvider);
                        },
                        icon: const Icon(Icons.refresh),
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
                      prefixIcon: Icon(Icons.apartment_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text('No property found. Add a property first.'),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue:
                  properties.any(
                        (property) => property.id == _selectedPropertyId,
                  )
                      ? _selectedPropertyId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Select property',
                    prefixIcon: Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final property in properties)
                      DropdownMenuItem<String>(
                        value: property.id,
                        child: Text(
                          '${property.name} • ${property.propertyCode}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                    setState(() {
                      _selectedPropertyId = value;

                      _selectedScopeId =
                      _scopeType == BillingScopeType.property
                          ? value
                          : null;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a property.';
                    }

                    return null;
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ================================================================
            // BILLING SCOPE
            // ================================================================
            Text(
              'Billing Scope',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<BillingScopeType>(
              initialValue: _scopeType,
              decoration: const InputDecoration(
                labelText: 'Apply rule to',
                prefixIcon: Icon(Icons.account_tree_outlined),
                border: OutlineInputBorder(),
              ),
              items: BillingScopeType.values.map((type) {
                return DropdownMenuItem<BillingScopeType>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_scopeTypeIcon(type), size: 20),
                      const SizedBox(width: 10),
                      Text(_scopeTypeLabel(type)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isSaving ? null : _changeScopeType,
            ),

            const SizedBox(height: 12),

            _buildScopeSelector(context, theme),

            const SizedBox(height: 24),

            // ================================================================
            // CHARGE TYPE
            // ================================================================
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
                prefixIcon: Icon(Icons.receipt_long_outlined),
                border: OutlineInputBorder(),
              ),
              items: BillingChargeType.values.map((type) {
                return DropdownMenuItem<BillingChargeType>(
                  value: type,
                  child: Text(_chargeTypeLabel(type)),
                );
              }).toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _chargeType = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // ================================================================
            // TITLE
            // ================================================================
            Text(
              'Title',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _titleController,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Optional title',
                hintText: 'Example: Monthly water charge',
                prefixIcon: Icon(Icons.title_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_chargeType == BillingChargeType.other &&
                    (value == null || value
                        .trim()
                        .isEmpty)) {
                  return 'Please enter a title for this charge.';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            // ================================================================
            // AMOUNT TYPE
            // ================================================================
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
                  icon: Icon(Icons.lock_outline),
                  label: Text('Fixed'),
                ),
                ButtonSegment<BillingValueType>(
                  value: BillingValueType.variable,
                  icon: Icon(Icons.tune_outlined),
                  label: Text('Variable'),
                ),
              ],
              selected: {_valueType},
              onSelectionChanged: _isSaving
                  ? null
                  : (selection) {
                if (selection.isEmpty) {
                  return;
                }

                setState(() {
                  _valueType = selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // ================================================================
            // AMOUNT
            // ================================================================
            Text(
              'Amount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _amountController,
              enabled: !_isSaving && _valueType == BillingValueType.fixed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '৳ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_valueType == BillingValueType.variable) {
                  return null;
                }

                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Please enter an amount.';
                }

                final amount = double.tryParse(text);

                if (amount == null) {
                  return 'Enter a valid amount.';
                }

                if (amount < 0) {
                  return 'Amount cannot be negative.';
                }

                return null;
              },
            ),

            if (_valueType == BillingValueType.variable) ...[
              const SizedBox(height: 8),
              Text(
                'Variable bills will use the actual amount when the monthly bill is generated.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ================================================================
            // EFFECTIVE MONTH
            // ================================================================
            Text(
              'Effective Month',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            FormField<DateTime>(
              validator: (value) {
                if (_effectiveMonth == null) {
                  return 'Please select an effective month.';
                }

                return null;
              },
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isSaving ? null : _selectEffectiveMonth,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Rule starts from',
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          border: const OutlineInputBorder(),
                          errorText: field.errorText,
                        ),
                        child: Text(
                          _effectiveMonth == null
                              ? 'Select effective month'
                              : _formatMonth(_effectiveMonth!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This rule will apply from the selected billing month.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ================================================================
            // ACTIVE
            // ================================================================
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Active billing rule'),
                subtitle: const Text(
                  'Inactive rules will not be used for new monthly bills.',
                ),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 32),

            // ================================================================
            // SAVE
            // ================================================================
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save Billing Rule'),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'The rule will be used by monthly bill generation from the selected effective month.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SCOPE SELECTOR
  // ========================================================================

  Widget _buildScopeSelector(BuildContext context, ThemeData theme) {
    final propertyId = _selectedPropertyId?.trim();

    if (propertyId == null || propertyId.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Scope',
          border: OutlineInputBorder(),
        ),
        child: Text('Select a property first.'),
      );
    }

    switch (_scopeType) {
      case BillingScopeType.property:
        return const InputDecorator(
          decoration: InputDecoration(
            labelText: 'Scope',
            prefixIcon: Icon(Icons.apartment_outlined),
            border: OutlineInputBorder(),
          ),
          child: Text('Entire Property'),
        );

      case BillingScopeType.floor:
        return _buildFloorSelector(propertyId);

      case BillingScopeType.unit:
        return _buildUnitSelector(propertyId);

      case BillingScopeType.tenant:
        return _buildTenantSelector(propertyId);
    }
  }

  // ========================================================================
  // FLOOR SELECTOR
  // ========================================================================

  Widget _buildFloorSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));

    return unitsAsync.when(
      loading: () {
        return const InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select floor',
            prefixIcon: Icon(Icons.layers_outlined),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading floors...'),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Select floor',
            prefixIcon: Icon(Icons.layers_outlined),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Unable to load floors.')),
              IconButton(
                tooltip: 'Retry',
                onPressed: () {
                  ref.invalidate(propertyUnitsProvider(propertyId));
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
      data: (units) {
        final floors = _getFloorNumbers(units);

        if (floors.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select floor',
              prefixIcon: Icon(Icons.layers_outlined),
              border: OutlineInputBorder(),
            ),
            child: Text('No floor found. Add units first.'),
          );
        }

        final selectedFloor = _selectedScopeId == null
            ? null
            : int.tryParse(_selectedScopeId!);

        return DropdownButtonFormField<int>(
          initialValue: floors.contains(selectedFloor) ? selectedFloor : null,
          decoration: const InputDecoration(
            labelText: 'Select floor',
            prefixIcon: Icon(Icons.layers_outlined),
            border: OutlineInputBorder(),
          ),
          items: floors.map((floor) {
            return DropdownMenuItem<int>(
              value: floor,
              child: Text(_floorLabel(floor)),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
            setState(() {
              _selectedScopeId = value?.toString();
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a floor.';
            }

            return null;
          },
        );
      },
    );
  }

  // ========================================================================
  // UNIT SELECTOR
  // ========================================================================

  Widget _buildUnitSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));

    return unitsAsync.when(
      loading: () {
        return const InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select unit',
            prefixIcon: Icon(Icons.door_front_door_outlined),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading units...'),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Select unit',
            prefixIcon: Icon(Icons.door_front_door_outlined),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Unable to load units.')),
              IconButton(
                tooltip: 'Retry',
                onPressed: () {
                  ref.invalidate(propertyUnitsProvider(propertyId));
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
      data: (units) {
        if (units.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select unit',
              prefixIcon: Icon(Icons.door_front_door_outlined),
              border: OutlineInputBorder(),
            ),
            child: Text('No unit found. Add a unit first.'),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: units.any((unit) => unit.id == _selectedScopeId)
              ? _selectedScopeId
              : null,
          decoration: const InputDecoration(
            labelText: 'Select unit',
            prefixIcon: Icon(Icons.door_front_door_outlined),
            border: OutlineInputBorder(),
          ),
          items: units.map((unit) {
            return DropdownMenuItem<String>(
              value: unit.id,
              child: Text(
                '${_unitLabel(unit)} • '
                    '${_floorLabel(unit.floorNumber)}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
            setState(() {
              _selectedScopeId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a unit.';
            }

            return null;
          },
        );
      },
    );
  }

  // ========================================================================
  // TENANT SELECTOR
  // ========================================================================

  Widget _buildTenantSelector(String propertyId) {
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));

    return tenantsAsync.when(
      loading: () {
        return const InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select tenant',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading tenants...'),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Select tenant',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Unable to load tenants.')),
              IconButton(
                tooltip: 'Retry',
                onPressed: () {
                  ref.invalidate(propertyTenantsProvider(propertyId));
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
      data: (tenants) {
        if (tenants.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select tenant',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            child: Text('No tenant found for this property.'),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: tenants.any((tenant) => tenant.id == _selectedScopeId)
              ? _selectedScopeId
              : null,
          decoration: const InputDecoration(
            labelText: 'Select tenant',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          items: tenants.map((tenant) {
            return DropdownMenuItem<String>(
              value: tenant.id,
              child: Text(
                _tenantLabel(tenant),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) {
            setState(() {
              _selectedScopeId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a tenant.';
            }

            return null;
          },
        );
      },
    );
  }
}
