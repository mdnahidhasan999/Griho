// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../providers/owner_tenants_provider.dart';
import '../providers/property_tenants_provider.dart';
import '../widgets/tenant_ui_helpers.dart';

class StartNewTenancyScreen extends ConsumerStatefulWidget {
  final Tenant tenant;

  const StartNewTenancyScreen({super.key, required this.tenant});

  @override
  ConsumerState<StartNewTenancyScreen> createState() =>
      _StartNewTenancyScreenState();
}

class _StartNewTenancyScreenState extends ConsumerState<StartNewTenancyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rentController = TextEditingController();

  String? _selectedPropertyId;
  Unit? _selectedUnit;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _rentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;

    if (tenant.status != TenantStatus.inactive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Start New Tenancy')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.close_circle,
              title: 'Tenant is Already Active',
              subtitle:
              'This tenant currently has an active tenancy. A new tenancy agreement can only be initiated for inactive or vacated tenants.',
              actionLabel: 'Go Back',
              onAction: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }

    if (tenant.accountStatus != TenantAccountStatus.registered) {
      return Scaffold(
        appBar: AppBar(title: const Text('Start New Tenancy')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.user_remove,
              title: 'Account Not Registered',
              subtitle:
              'The tenant must register their personal Griho account before an official tenancy agreement can be initiated.',
              actionLabel: 'Go Back',
              onAction: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }

    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Start New Tenancy')),
      body: propertiesAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading properties...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load properties',
              subtitle: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentOwnerPropertiesProvider),
            ),
          ),
        ),
        data: (properties) {
          final activeProperties = properties
              .where((property) => property.status == PropertyStatus.active)
              .toList();

          if (_selectedPropertyId != null &&
              !activeProperties.any((p) => p.id == _selectedPropertyId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _selectedPropertyId = null;
                _selectedUnit = null;
                _rentController.clear();
              });
            });
          }

          return _buildContent(
            context: context,
            tenant: tenant,
            properties: activeProperties,
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Tenant tenant,
    required List<Property> properties,
  }) {
    final selectedProperty = _getSelectedProperty(properties);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTenantHeaderCard(tenant),
              const SizedBox(height: 18),
              GrihoSectionCard(
                title: '1. Select Property',
                subtitle: 'Choose an active building for the new lease',
                icon: Iconsax.buildings_2,
                children: [
                  if (properties.isEmpty)
                    const GrihoStatusState(
                      icon: Iconsax.buildings_2,
                      title: 'No active properties',
                      subtitle: 'No active properties are available.',
                    )
                  else
                    _buildPropertyDropdown(properties),
                ],
              ),
              const SizedBox(height: 18),
              if (selectedProperty != null) ...[
                GrihoSectionCard(
                  title: '2. Select Available Unit',
                  subtitle: 'Pick a vacant apartment or commercial space',
                  icon: Iconsax.home_2,
                  children: [_buildUnitSection(selectedProperty)],
                ),
                const SizedBox(height: 18),
                GrihoSectionCard(
                  title: '3. Rental Agreement',
                  subtitle: 'Specify recurring monthly rent amount',
                  icon: Iconsax.wallet_3,
                  children: [_buildRentInput()],
                ),
              ],
              const SizedBox(height: 28),
              GrihoPrimaryButton(
                label: _isSubmitting
                    ? 'Starting Tenancy...'
                    : 'Start New Tenancy',
                icon: Iconsax.tick_circle,
                isLoading: _isSubmitting,
                onPressed: _canSubmit(selectedProperty: selectedProperty)
                    ? () => _confirmStartNewTenancy(property: selectedProperty!)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantHeaderCard(Tenant tenant) {
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
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              tenantInitials(tenant.name),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Iconsax.call,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tenant.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (tenant.email != null &&
                    tenant.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Iconsax.sms,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tenant.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: GrihoColors.emerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.verify,
                            size: 12,
                            color: GrihoColors.emerald,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Registered User',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: GrihoColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TenantStatusChip(status: tenant.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyDropdown(List<Property> properties) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPropertyId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Target Property',
        prefixIcon: Icon(
          Iconsax.buildings_2,
          color: GrihoColors.emerald,
          size: 20,
        ),
      ),
      hint: const Text('Select property building'),
      items: properties.map((property) {
        return DropdownMenuItem<String>(
          value: property.id,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  property.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                property.propertyCode,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: _isSubmitting
          ? null
          : (propertyId) {
        setState(() {
          _selectedPropertyId = propertyId;
          _selectedUnit = null;
          _rentController.clear();
        });
      },
    );
  }

  Property? _getSelectedProperty(List<Property> properties) {
    final selectedPropertyId = _selectedPropertyId;
    if (selectedPropertyId == null) {
      return null;
    }
    for (final property in properties) {
      if (property.id == selectedPropertyId) {
        return property;
      }
    }
    return null;
  }

  Widget _buildUnitSection(Property property) {
    final propertyId = property.id;
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));

    return unitsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => GrihoStatusState(
        icon: Iconsax.warning_2,
        title: 'Unable to load units',
        subtitle: error.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(propertyUnitsProvider(propertyId)),
      ),
      data: (units) {
        final availableUnits = units
            .where((unit) => unit.status == UnitStatus.available)
            .toList();

        if (availableUnits.isEmpty) {
          return const GrihoStatusState(
            icon: Iconsax.home_2,
            title: 'No available units',
            subtitle: 'No vacant units found in this property.',
          );
        }

        return _buildUnitList(availableUnits);
      },
    );
  }

  Widget _buildUnitList(List<Unit> units) {
    final theme = Theme.of(context);

    return RadioGroup<String>(
      groupValue: _selectedUnit?.id,
      onChanged: (unitId) {
        if (_isSubmitting || unitId == null) {
          return;
        }
        final selected = units.where((u) => u.id == unitId).firstOrNull;
        if (selected != null) {
          setState(() => _selectedUnit = selected);
        }
      },
      child: Column(
        children: units.map((unit) {
          final isSelected = _selectedUnit?.id == unit.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _selectedUnit = unit),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(value: unit.id),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.name?.trim().isNotEmpty == true
                                  ? unit.name!
                                  : 'Unit ${unit.unitNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Vacant',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRentInput() {
    return TextFormField(
      controller: _rentController,
      enabled: !_isSubmitting,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: const InputDecoration(
        labelText: 'Initial Monthly Rent',
        hintText: 'e.g. 15000',
        prefixText: '৳ ',
        suffixText: '/ month',
        prefixIcon: Icon(
          Iconsax.money_2,
          color: GrihoColors.emerald,
          size: 20,
        ),
      ),
      onChanged: (_) => setState(() {}),
      validator: (val) {
        final amount = double.tryParse(val?.trim() ?? '');
        if (amount == null || amount <= 0) {
          return 'Please enter a valid monthly rent amount.';
        }
        return null;
      },
    );
  }

  double? _getRentAmount() {
    final value = _rentController.text.trim();
    if (value.isEmpty) {
      return null;
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return null;
    }
    return amount;
  }

  bool _canSubmit({required Property? selectedProperty}) {
    return !_isSubmitting &&
        selectedProperty != null &&
        _selectedUnit != null &&
        _getRentAmount() != null;
  }

  Future<void> _confirmStartNewTenancy({required Property property}) async {
    FocusScope.of(context).unfocus();
    final unit = _selectedUnit;
    if (unit == null) {
      return;
    }

    final amount = _getRentAmount();
    if (amount == null) {
      GrihoFeedback.showError(
        context,
        'Please enter a valid monthly rent amount.',
      );
      return;
    }

    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start New Tenancy?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start a new active tenancy for ${widget.tenant.name} in ${property.name}, Unit ${unit.unitNumber}?',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Rent',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '৳${formatTenantAmount(amount)} / month',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm & Start'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _startNewTenancy(property: property, unit: unit, amount: amount);
  }

  Future<void> _startNewTenancy({
    required Property property,
    required Unit unit,
    required double amount,
  }) async {
    setState(() => _isSubmitting = true);

    final startedTenant = await ref
        .read(tenantControllerProvider.notifier)
        .startNewTenancy(
      tenantId: widget.tenant.id,
      propertyId: property.id,
      unitId: unit.id,
      amount: amount,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (startedTenant == null) {
      final state = ref.read(tenantControllerProvider);
      GrihoFeedback.showError(
        context,
        state.error?.toString().replaceFirst('Bad state: ', '') ??
            'Unable to start new tenancy.',
      );
      return;
    }

    ref.invalidate(currentOwnerPropertiesProvider);
    ref.invalidate(propertyUnitsProvider(property.id));
    ref.invalidate(propertyTenantsProvider(property.id));
    ref.invalidate(ownerTenantsProvider);

    GrihoFeedback.showSuccess(context, 'New tenancy started successfully.');
    Navigator.of(context).pop(true);
  }
}
