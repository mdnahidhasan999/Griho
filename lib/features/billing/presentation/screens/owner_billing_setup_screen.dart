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

  DateTime? _effectiveMonth;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _effectiveMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

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

    setState(() {
      _effectiveMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    });
  }

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

  List<int> _getFloorNumbers(List<Unit> units) {
    final floors = <int>{};
    for (final unit in units) {
      floors.add(unit.floorNumber);
    }
    return floors.toList()..sort();
  }

  String _floorLabel(int floorNumber) {
    if (floorNumber == 0) return 'Ground Floor';
    if (floorNumber == 1) return '1st Floor';
    if (floorNumber == 2) return '2nd Floor';
    if (floorNumber == 3) return '3rd Floor';
    return '$floorNumber Floor';
  }

  String _unitLabel(Unit unit) {
    final unitNumber = unit.unitNumber.trim();
    if (unit.name != null && unit.name!.trim().isNotEmpty) {
      return '${unit.name!.trim()} • Unit $unitNumber';
    }
    return 'Unit $unitNumber';
  }

  String _tenantLabel(Tenant tenant) {
    final name = tenant.name.trim();
    if (tenant.phone.trim().isNotEmpty) {
      return '$name • ${tenant.phone.trim()}';
    }
    return name;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPropertyId == null || _selectedPropertyId!.trim().isEmpty) {
      _showMessage('Please select a property.');
      return;
    }

    if (_selectedScopeId == null || _selectedScopeId!.trim().isEmpty) {
      _showMessage('Please select the specific scope target.');
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
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount < 0) {
      _showMessage('Please enter a valid amount.');
      return;
    }

    final title = _titleController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final effectiveTo = _valueType == BillingValueType.variable
          ? DateTime(_effectiveMonth!.year, _effectiveMonth!.month + 1, 1)
          : null;

      final request = CreateBillingRuleRequest(
        ownerId: ownerId,
        propertyId: _selectedPropertyId!.trim(),
        scopeType: _scopeType,
        scopeId: _selectedScopeId!.trim(),
        chargeType: _chargeType,
        valueType: _valueType,
        amount: amount,
        title: title.isEmpty ? null : title,
        effectiveFrom: _effectiveMonth!,
        effectiveTo: effectiveTo,
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

      if (context.mounted) {
        Navigator.of(context).pop(rule);
      }
    } catch (error) {
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

  String _cleanErrorMessage(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }
    if (message.startsWith('Invalid argument(s): ')) {
      return message.substring(21);
    }
    return message;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _buildSectionCard(
              title: '1. Target & Scope',
              subtitle: 'Where will this rule be applied?',
              children: [
                propertiesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) =>
                      const Text('Unable to load properties.'),
                  data: (properties) {
                    if (properties.isEmpty) {
                      return const Text(
                        'No property found. Add property first.',
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue:
                          properties.any((p) => p.id == _selectedPropertyId)
                          ? _selectedPropertyId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Select Property',
                        prefixIcon: Icon(Icons.apartment_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final property in properties)
                          DropdownMenuItem<String>(
                            value: property.id,
                            child: Text(
                              '${property.name} (${property.propertyCode})',
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
                      validator: (value) =>
                          value == null ? 'Please select a property.' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BillingScopeType>(
                  initialValue: _scopeType,
                  decoration: const InputDecoration(
                    labelText: 'Apply Rule To',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: BillingScopeType.values.map((type) {
                    return DropdownMenuItem<BillingScopeType>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_scopeTypeIcon(type), size: 18),
                          const SizedBox(width: 8),
                          Text(_scopeTypeLabel(type)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving ? null : _changeScopeType,
                ),
                const SizedBox(height: 14),
                _buildScopeSelector(context),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: '2. Charge Information',
              subtitle: 'Configure charge category and amount.',
              children: [
                DropdownButtonFormField<BillingChargeType>(
                  initialValue: _chargeType,
                  decoration: const InputDecoration(
                    labelText: 'Charge Category',
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
                          if (value != null) {
                            setState(() => _chargeType = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Custom Label / Note (Optional)',
                    hintText: 'e.g. October Motor Service',
                    prefixIcon: Icon(Icons.title_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_chargeType == BillingChargeType.other &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Title is required for "Other" charge type.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<BillingValueType>(
                  segments: const [
                    ButtonSegment(
                      value: BillingValueType.fixed,
                      label: Text('Fixed (Every Month)'),
                      icon: Icon(Icons.lock_clock_outlined),
                    ),
                    ButtonSegment(
                      value: BillingValueType.variable,
                      label: Text('Variable (This Month)'),
                      icon: Icon(Icons.tune_outlined),
                    ),
                  ],
                  selected: {_valueType},
                  onSelectionChanged: _isSaving
                      ? null
                      : (set) => setState(() => _valueType = set.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  enabled: !_isSaving,
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
                  validator: (val) {
                    final amount = double.tryParse(val?.trim() ?? '');
                    if (amount == null || amount < 0) {
                      return 'Enter a valid positive amount.';
                    }
                    return null;
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: '3. Schedule & Activation',
              subtitle: 'Select month and activation state.',
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isSaving ? null : _selectEffectiveMonth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Effective Month',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _effectiveMonth == null
                          ? 'Select month'
                          : _formatMonth(_effectiveMonth!),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Material দিয়ে র‍্যাপ করায় assertion এরর সমাধান হয়েছে
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Rule is Active',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Inactive rules will be skipped during generation.',
                    ),
                    value: _isActive,
                    onChanged: _isSaving
                        ? null
                        : (val) => setState(() => _isActive = val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving ? 'Creating Rule...' : 'Save & Activate Rule',
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
    );
  }

  // Card ব্যবহার করে তৈরি সেকশন, যা ভেতরে ListTile থাকলে কোনো এরর দেয় না
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector(BuildContext context) {
    final propertyId = _selectedPropertyId?.trim();

    if (propertyId == null || propertyId.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Scope Detail',
          border: OutlineInputBorder(),
        ),
        child: Text('Please choose a property first.'),
      );
    }

    switch (_scopeType) {
      case BillingScopeType.property:
        return const SizedBox.shrink();

      case BillingScopeType.floor:
        return _buildFloorSelector(propertyId);

      case BillingScopeType.unit:
        return _buildUnitSelector(propertyId);

      case BillingScopeType.tenant:
        return _buildTenantSelector(propertyId);
    }
  }

  Widget _buildFloorSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    return unitsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => const Text('Error loading floors.'),
      data: (units) {
        final floors = _getFloorNumbers(units);
        if (floors.isEmpty) {
          return const Text('No units/floors added to this property.');
        }

        final selectedFloor = _selectedScopeId == null
            ? null
            : int.tryParse(_selectedScopeId!);
        return DropdownButtonFormField<int>(
          initialValue: floors.contains(selectedFloor) ? selectedFloor : null,
          decoration: const InputDecoration(
            labelText: 'Target Floor',
            prefixIcon: Icon(Icons.layers_outlined),
            border: OutlineInputBorder(),
          ),
          items: floors
              .map(
                (f) => DropdownMenuItem(value: f, child: Text(_floorLabel(f))),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (val) => setState(() => _selectedScopeId = val?.toString()),
          validator: (val) => val == null ? 'Please select a floor.' : null,
        );
      },
    );
  }

  Widget _buildUnitSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    return unitsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => const Text('Error loading units.'),
      data: (units) {
        if (units.isEmpty) {
          return const Text('No units found in this property.');
        }

        return DropdownButtonFormField<String>(
          initialValue: units.any((u) => u.id == _selectedScopeId)
              ? _selectedScopeId
              : null,
          decoration: const InputDecoration(
            labelText: 'Target Unit',
            prefixIcon: Icon(Icons.door_front_door_outlined),
            border: OutlineInputBorder(),
          ),
          items: units
              .map(
                (u) =>
                    DropdownMenuItem(value: u.id, child: Text(_unitLabel(u))),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (val) => setState(() => _selectedScopeId = val),
          validator: (val) => val == null ? 'Please select a unit.' : null,
        );
      },
    );
  }

  Widget _buildTenantSelector(String propertyId) {
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));
    return tenantsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => const Text('Error loading tenants.'),
      data: (tenants) {
        if (tenants.isEmpty) {
          return const Text('No active tenants found in this property.');
        }

        return DropdownButtonFormField<String>(
          initialValue: tenants.any((t) => t.id == _selectedScopeId)
              ? _selectedScopeId
              : null,
          decoration: const InputDecoration(
            labelText: 'Target Tenant',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          items: tenants
              .map(
                (t) =>
                    DropdownMenuItem(value: t.id, child: Text(_tenantLabel(t))),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (val) => setState(() => _selectedScopeId = val),
          validator: (val) => val == null ? 'Please select a tenant.' : null,
        );
      },
    );
  }
}
