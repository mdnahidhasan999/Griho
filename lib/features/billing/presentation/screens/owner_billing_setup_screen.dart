// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../controllers/generate_monthly_charges_controller.dart';
import '../providers/billing_rule_provider.dart';
import '../widgets/billing_ui_helpers.dart';

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

  String? _resolvePropertyId(List<Property> properties) {
    if (_selectedPropertyId != null &&
        properties.any((p) => p.id == _selectedPropertyId)) {
      return _selectedPropertyId;
    }
    if (properties.length == 1) {
      return properties.first.id;
    }
    return null;
  }

  String? _resolveScopeId(String? effectivePropertyId) {
    if (_scopeType == BillingScopeType.property) {
      return effectivePropertyId;
    }
    return _selectedScopeId;
  }

  Future<void> _selectEffectiveMonth() async {
    final now = DateTime.now();
    final initialDate = _effectiveMonth ?? DateTime(now.year, now.month, 1);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select effective billing month',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    });
  }

  String _scopeTypeLabel(BillingScopeType type) => switch (type) {
    BillingScopeType.property => 'Entire Property',
    BillingScopeType.floor => 'Specific Floor',
    BillingScopeType.unit => 'Specific Unit',
    BillingScopeType.tenant => 'Specific Tenant',
  };

  IconData _scopeTypeIcon(BillingScopeType type) => switch (type) {
    BillingScopeType.property => Iconsax.buildings_2,
    BillingScopeType.floor => Iconsax.layer,
    BillingScopeType.unit => Iconsax.home_2,
    BillingScopeType.tenant => Iconsax.user,
  };

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
    final floors = <int>{for (final unit in units) unit.floorNumber};
    return floors.toList()..sort();
  }

  String _floorLabel(int floorNumber) => switch (floorNumber) {
    0 => 'Ground Floor',
    1 => '1st Floor',
    2 => '2nd Floor',
    3 => '3rd Floor',
    _ => 'Floor $floorNumber',
  };

  String _unitLabel(Unit unit) {
    final unitNumber = unit.unitNumber.trim();
    final customName = unit.name?.trim() ?? '';
    if (customName.isNotEmpty) {
      return '$customName (Unit $unitNumber)';
    }
    return 'Unit $unitNumber';
  }

  String? _unitSubtitle(Unit unit) {
    final parts = <String>[_floorLabel(unit.floorNumber)];
    if (unit.name != null && unit.name!.trim().isNotEmpty) {
      parts.add('Unit ${unit.unitNumber.trim()}');
    }
    return parts.join(' • ');
  }

  String _tenantLabel(Tenant tenant) => tenant.name.trim();

  String? _tenantSubtitle(Tenant tenant) {
    final phone = tenant.phone.trim();
    return phone.isNotEmpty ? phone : null;
  }

  Future<List<Tenant>> _loadFallbackActiveTenants(String propertyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', isEqualTo: 'active')
        .limit(200)
        .get();
    return snap.docs.map(TenantModel.fromFirestore).toList();
  }

  Future<void> _save(List<Property> properties) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final propertyId = _resolvePropertyId(properties)?.trim();
    if (propertyId == null || propertyId.isEmpty) {
      GrihoFeedback.showError(context, 'Please select a target property.');
      return;
    }

    final scopeId = _resolveScopeId(propertyId)?.trim();
    if (scopeId == null || scopeId.isEmpty) {
      GrihoFeedback.showError(context, 'Please select the specific target.');
      return;
    }

    if (_effectiveMonth == null) {
      GrihoFeedback.showError(context, 'Please select an effective month.');
      return;
    }

    final firebaseUser = ref.read(authStateProvider).value;
    if (firebaseUser == null) {
      GrihoFeedback.showError(context, 'You are not signed in.');
      return;
    }

    final selectedProperty = properties
        .where((p) => p.id == propertyId)
        .firstOrNull;
    final ownerId = (selectedProperty?.ownerId ?? firebaseUser.uid).trim();

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount < 0) {
      GrihoFeedback.showError(context, 'Please enter a valid positive amount.');
      return;
    }

    final title = _titleController.text.trim();

    setState(() => _isSaving = true);

    try {
      final effectiveTo = _valueType == BillingValueType.variable
          ? DateTime(_effectiveMonth!.year, _effectiveMonth!.month + 1, 1)
          : null;

      final request = CreateBillingRuleRequest(
        ownerId: ownerId,
        propertyId: propertyId,
        scopeType: _scopeType,
        scopeId: scopeId,
        chargeType: _chargeType,
        valueType: _valueType,
        amount: amount,
        title: title.isEmpty ? null : title,
        effectiveFrom: _effectiveMonth!,
        effectiveTo: effectiveTo,
        isActive: _isActive,
      );

      final rule = await ref.read(createBillingRuleProvider)(request);

      if (!mounted) {
        return;
      }

      ref.invalidate(
        propertyBillingRulesProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        )),
      );
      ref
          .read(generateMonthlyChargesControllerProvider.notifier)
          .invalidateMonthSyncLock(ownerId: ownerId, propertyId: propertyId);

      GrihoFeedback.showSuccess(context, 'Billing rule created successfully.');
      Navigator.of(context).pop(rule);
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final properties = propertiesAsync.value ?? const <Property>[];
    final effectivePropertyId = _resolvePropertyId(properties);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Billing Setup')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Iconsax.receipt_item,
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
                          'Configure Billing Rule',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set up automated monthly utility charges or recurring building expenses.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: '1. Target & Scope',
              subtitle: 'Select where this billing rule applies',
              icon: Iconsax.hierarchy,
              children: [
                propertiesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Unable to load properties.'),
                  data: (props) {
                    if (props.isEmpty) {
                      return const Text(
                        'No properties found. Please add a property first.',
                      );
                    }

                    final selectedProperty = props
                        .where((p) => p.id == effectivePropertyId)
                        .firstOrNull;

                    return GrihoPickerField<Property>(
                      label: 'Select Property',
                      hint: 'Choose a building',
                      sheetTitle: 'Select Property',
                      searchHint: 'Search by building name or code...',
                      icon: Iconsax.buildings_2,
                      items: props,
                      value: selectedProperty,
                      enabled: !_isSaving,
                      itemTitle: (p) => p.name,
                      itemSubtitle: (p) => p.propertyCode.trim().isNotEmpty
                          ? 'Code: ${p.propertyCode}'
                          : null,
                      onChanged: (property) {
                        setState(() {
                          _selectedPropertyId = property.id;
                          _selectedScopeId =
                              _scopeType == BillingScopeType.property
                              ? property.id
                              : null;
                        });
                      },
                      validator: (_) => effectivePropertyId == null
                          ? 'Please select a property.'
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                GrihoPickerField<BillingScopeType>(
                  label: 'Rule Scope Perimeter',
                  sheetTitle: 'Select Rule Scope',
                  icon: Iconsax.setting_4,
                  itemIcon: _scopeTypeIcon(_scopeType),
                  items: BillingScopeType.values,
                  value: _scopeType,
                  enabled: !_isSaving,
                  itemTitle: _scopeTypeLabel,
                  onChanged: _changeScopeType,
                ),

                if (_scopeType != BillingScopeType.property) ...[
                  const SizedBox(height: 16),
                  _buildScopeSelector(effectivePropertyId),
                ],
              ],
            ),
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: '2. Charge Information',
              subtitle: 'Specify category, recurrence, and amount',
              icon: Iconsax.wallet_3,
              children: [
                GrihoPickerField<BillingChargeType>(
                  label: 'Charge Category',
                  sheetTitle: 'Select Charge Category',
                  icon: Iconsax.category,
                  itemIcon: billingChargeTypeIcon(_chargeType),
                  items: BillingChargeType.values,
                  value: _chargeType,
                  enabled: !_isSaving,
                  itemTitle: billingChargeTypeLabel,
                  onChanged: (value) => setState(() => _chargeType = value),
                ),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Custom Label / Note (Optional)',
                    hintText: 'e.g. October Water Bill',
                    prefixIcon: Icon(
                      Iconsax.tag,
                      color: GrihoColors.emerald,
                      size: 19,
                    ),
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
                Text(
                  'Charge Type',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<BillingValueType>(
                  segments: const [
                    ButtonSegment(
                      value: BillingValueType.fixed,
                      label: Text('Fixed (Monthly)'),
                      icon: Icon(Iconsax.repeat, size: 16),
                    ),
                    ButtonSegment(
                      value: BillingValueType.variable,
                      label: Text('Variable (1 Mo)'),
                      icon: Icon(Iconsax.calendar_1, size: 16),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Charge Amount',
                    hintText: '0.00',
                    prefixText: '৳ ',
                    prefixIcon: Icon(
                      Iconsax.money_2,
                      color: GrihoColors.emerald,
                      size: 19,
                    ),
                  ),
                  validator: (val) {
                    final amount = double.tryParse(val?.trim() ?? '');
                    if (amount == null || !amount.isFinite || amount < 0) {
                      return 'Enter a valid positive amount.';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: '3. Schedule & Status',
              subtitle: 'Effective month and activation toggle',
              icon: Iconsax.calendar_1,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isSaving ? null : _selectEffectiveMonth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Effective Month',
                      prefixIcon: Icon(
                        Iconsax.calendar_1,
                        color: GrihoColors.emerald,
                        size: 19,
                      ),
                      suffixIcon: Icon(Iconsax.arrow_right_3, size: 16),
                    ),
                    child: Text(
                      _effectiveMonth == null
                          ? 'Select month'
                          : formatBillingMonthYear(_effectiveMonth!),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Activate Rule Immediately',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'This rule will be applied when generating monthly invoices.'
                        : 'Rule is deactivated and will be ignored during invoice generation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _isActive,
                  onChanged: _isSaving
                      ? null
                      : (val) => setState(() => _isActive = val),
                ),
              ],
            ),
            const SizedBox(height: 28),
            GrihoPrimaryButton(
              label: _isSaving
                  ? 'Creating Rule...'
                  : 'Save & Activate Billing Rule',
              icon: Iconsax.tick_circle,
              isLoading: _isSaving,
              onPressed: () => _save(properties),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector(String? selectedPropertyId) {
    final propertyId = selectedPropertyId?.trim();
    if (propertyId == null || propertyId.isEmpty) {
      return GrihoPickerField<String>(
        label: 'Scope Target',
        hint: 'Please choose a property first.',
        items: const [],
        value: null,
        enabled: false,
        itemTitle: (s) => s,
        onChanged: (_) {},
      );
    }

    return switch (_scopeType) {
      BillingScopeType.property => const SizedBox.shrink(),
      BillingScopeType.floor => _buildFloorSelector(propertyId),
      BillingScopeType.unit => _buildUnitSelector(propertyId),
      BillingScopeType.tenant => _buildTenantSelector(propertyId),
    };
  }

  Widget _buildFloorSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    return unitsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Error loading floors.'),
      data: (units) {
        final floors = _getFloorNumbers(units);
        if (floors.isEmpty) {
          return const Text('No units or floors found in this property.');
        }

        final selectedFloor = _selectedScopeId == null
            ? null
            : int.tryParse(_selectedScopeId!);
        final activeFloor =
            (selectedFloor != null && floors.contains(selectedFloor))
            ? selectedFloor
            : null;

        return GrihoPickerField<int>(
          label: 'Target Floor',
          hint: 'Choose a floor',
          sheetTitle: 'Select Target Floor',
          searchHint: 'Search floor...',
          icon: Iconsax.layer,
          items: floors,
          value: activeFloor,
          enabled: !_isSaving,
          itemTitle: _floorLabel,
          onChanged: (val) => setState(() => _selectedScopeId = val.toString()),
          validator: (_) =>
              activeFloor == null ? 'Please select a floor.' : null,
        );
      },
    );
  }

  Widget _buildUnitSelector(String propertyId) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    return unitsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Error loading units.'),
      data: (units) {
        if (units.isEmpty) {
          return const Text('No units found in this property.');
        }

        final selectedUnit = units
            .where((u) => u.id == _selectedScopeId)
            .firstOrNull;

        return GrihoPickerField<Unit>(
          label: 'Target Unit',
          hint: 'Choose a unit',
          sheetTitle: 'Select Target Unit',
          searchHint: 'Search by unit or floor...',
          icon: Iconsax.home_2,
          items: units,
          value: selectedUnit,
          enabled: !_isSaving,
          itemTitle: _unitLabel,
          itemSubtitle: _unitSubtitle,
          onChanged: (unit) => setState(() => _selectedScopeId = unit.id),
          validator: (_) =>
              selectedUnit == null ? 'Please select a unit.' : null,
        );
      },
    );
  }

  Widget _buildTenantSelector(String propertyId) {
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));
    return tenantsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => FutureBuilder<List<Tenant>>(
        future: _loadFallbackActiveTenants(propertyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final fallbackTenants = snapshot.data ?? const <Tenant>[];
          if (fallbackTenants.isEmpty) {
            return const Text('No active tenants found in this property.');
          }
          return _tenantPicker(fallbackTenants);
        },
      ),
      data: (tenants) {
        final activeTenants = tenants
            .where((t) => t.status == TenantStatus.active)
            .toList();

        if (activeTenants.isEmpty) {
          return const Text('No active tenants found in this property.');
        }
        return _tenantPicker(activeTenants);
      },
    );
  }

  Widget _tenantPicker(List<Tenant> activeTenants) {
    final selectedTenant = activeTenants
        .where((t) => t.id == _selectedScopeId)
        .firstOrNull;

    return GrihoPickerField<Tenant>(
      label: 'Target Tenant',
      hint: 'Choose an active tenant',
      sheetTitle: 'Select Target Tenant',
      searchHint: 'Search by name or phone...',
      icon: Iconsax.user,
      items: activeTenants,
      value: selectedTenant,
      enabled: !_isSaving,
      itemTitle: _tenantLabel,
      itemSubtitle: _tenantSubtitle,
      onChanged: (tenant) => setState(() => _selectedScopeId = tenant.id),
      validator: (_) =>
          selectedTenant == null ? 'Please select a tenant.' : null,
    );
  }
}
