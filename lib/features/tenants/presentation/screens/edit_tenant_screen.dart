// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../widgets/tenant_ui_helpers.dart';

class EditTenantScreen extends ConsumerStatefulWidget {
  final Tenant tenant;

  const EditTenantScreen({super.key, required this.tenant});

  @override
  ConsumerState<EditTenantScreen> createState() => _EditTenantScreenState();
}

class _EditTenantScreenState extends ConsumerState<EditTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _nidController;

  Property? _selectedProperty;
  Unit? _selectedUnit;
  late String _phoneNumber;

  bool get _isActive => widget.tenant.status == TenantStatus.active;

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    _nameController = TextEditingController(text: tenant.name);
    _emailController = TextEditingController(text: tenant.email ?? '');
    _nidController = TextEditingController(text: tenant.nidNumber ?? '');
    _phoneNumber = tenant.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nidController.dispose();
    super.dispose();
  }

  String? _getValidatedPhone() {
    final value = _phoneNumber.trim();
    if (!PhoneNumberUtils.isValid(value)) {
      return null;
    }
    return PhoneNumberUtils.normalize(value);
  }

  Future<void> _updateTenant() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;

    if (property == null) {
      GrihoFeedback.showError(context, 'Please select a property building.');
      return;
    }
    if (unit == null) {
      GrihoFeedback.showError(context, 'Please select a unit space.');
      return;
    }

    final phone = _getValidatedPhone();
    if (phone == null) {
      GrihoFeedback.showError(
        context,
        'Please enter a valid international phone number.',
      );
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final nid = _nidController.text.trim();

    // Skip Firestore write if nothing changed.
    final unchanged =
        property.id == widget.tenant.propertyId &&
            unit.id == widget.tenant.unitId &&
            name == widget.tenant.name.trim() &&
            phone == widget.tenant.phone.trim() &&
            email == (widget.tenant.email?.trim() ?? '') &&
            nid == (widget.tenant.nidNumber?.trim() ?? '');

    if (unchanged) {
      GrihoFeedback.showInfo(context, 'No changes to save.');
      Navigator.of(context).pop();
      return;
    }

    final updatedTenant = widget.tenant.copyWith(
      propertyId: property.id,
      unitId: unit.id,
      name: name,
      phone: phone,
      email: email.isEmpty ? null : email,
      nidNumber: nid.isEmpty ? null : nid,
      updatedAt: DateTime.now(),
    );

    final result = await ref
        .read(tenantControllerProvider.notifier)
        .updateTenant(updatedTenant);

    if (!mounted) {
      return;
    }

    if (result == null) {
      final state = ref.read(tenantControllerProvider);
      GrihoFeedback.showError(
        context,
        state.error?.toString().replaceFirst('Bad state: ', '') ??
            'Unable to update tenant.',
      );
      return;
    }

    GrihoFeedback.showSuccess(context, 'Tenant record updated successfully.');
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final tenantState = ref.watch(tenantControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Edit Tenant')),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () => const GrihoLoadingView(message: 'Loading details...'),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load properties',
                subtitle: 'Please check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(currentOwnerPropertiesProvider),
              ),
            ),
          ),
          data: (properties) {
            if (properties.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: GrihoStatusState(
                    icon: Iconsax.buildings_2,
                    title: 'No properties available',
                    subtitle: 'Add a property first.',
                  ),
                ),
              );
            }

            final initialProperty =
                properties
                    .where(
                      (p) =>
                  p.id ==
                      (_selectedProperty?.id ?? widget.tenant.propertyId),
                )
                    .firstOrNull ??
                    properties.first;

            _selectedProperty ??= initialProperty;

            final selectedPropertyId = _selectedProperty?.id;
            final unitsAsync = selectedPropertyId == null
                ? const AsyncValue<List<Unit>>.data([])
                : ref.watch(propertyUnitsProvider(selectedPropertyId));

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TenantHeaderCard(
                      name: _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : widget.tenant.name,
                      phone: _phoneNumber,
                      status: widget.tenant.status,
                    ),
                    const SizedBox(height: 18),
                    GrihoSectionCard(
                      title: '1. Allocation & Unit',
                      subtitle: _isActive
                          ? 'End active tenancy first to move resident to another unit'
                          : 'Target building and residential unit assignment',
                      icon: Iconsax.buildings_2,
                      children: [
                        DropdownButtonFormField<Property>(
                          initialValue: _selectedProperty,
                          decoration: const InputDecoration(
                            labelText: 'Property Building',
                            prefixIcon: Icon(
                              Iconsax.buildings_2,
                              color: GrihoColors.emerald,
                              size: 20,
                            ),
                          ),
                          items: properties.map((property) {
                            return DropdownMenuItem<Property>(
                              value: property,
                              child: Text(
                                '${property.name} (${property.propertyCode})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (tenantState.isLoading || _isActive)
                              ? null
                              : (property) {
                            setState(() {
                              _selectedProperty = property;
                              _selectedUnit = null;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a property.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        unitsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text(
                            'Unable to load units: $error',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          data: (units) {
                            if (_selectedProperty == null || units.isEmpty) {
                              return const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Assigned Unit',
                                  prefixIcon: Icon(Iconsax.home_2, size: 20),
                                ),
                                child: Text('No units available'),
                              );
                            }

                            final initialUnit = units
                                .where(
                                  (u) =>
                              u.id ==
                                  (_selectedUnit?.id ??
                                      widget.tenant.unitId),
                            )
                                .firstOrNull;

                            _selectedUnit ??= initialUnit;

                            return DropdownButtonFormField<Unit>(
                              initialValue: units.contains(_selectedUnit)
                                  ? _selectedUnit
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Unit',
                                prefixIcon: Icon(
                                  Iconsax.home_2,
                                  color: GrihoColors.emerald,
                                  size: 20,
                                ),
                              ),
                              items: units.map((unit) {
                                return DropdownMenuItem<Unit>(
                                  value: unit,
                                  child: Text(
                                    'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (tenantState.isLoading || _isActive)
                                  ? null
                                  : (unit) =>
                                  setState(() => _selectedUnit = unit),
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a unit.';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GrihoSectionCard(
                      title: '2. Personal Credentials',
                      subtitle: 'Contact details and resident identity',
                      icon: Iconsax.user,
                      children: [
                        GrihoTextField(
                          controller: _nameController,
                          label: 'Full Legal Name',
                          hint: 'Enter resident full name',
                          prefixIcon: Iconsax.user,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          enabled: !tenantState.isLoading,
                          validator: GrihoValidators.name,
                        ),
                        const SizedBox(height: 16),
                        IntlPhoneField(
                          initialValue: widget.tenant.phone,
                          enabled: !tenantState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Verified Phone Number',
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (phone) =>
                          _phoneNumber = phone.completeNumber,
                          validator: (phone) {
                            if (phone == null ||
                                phone.completeNumber.trim().isEmpty) {
                              return 'Please enter phone number.';
                            }
                            if (!PhoneNumberUtils.isValid(
                              phone.completeNumber,
                            )) {
                              return 'Please enter a valid international phone number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        GrihoTextField(
                          controller: _emailController,
                          label: 'Email Address (Optional)',
                          hint: 'e.g. tenant@example.com',
                          prefixIcon: Iconsax.sms,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !tenantState.isLoading,
                          validator: GrihoValidators.optionalEmail,
                        ),
                        const SizedBox(height: 16),
                        GrihoTextField(
                          controller: _nidController,
                          label: 'National ID / NID (Optional)',
                          hint: 'Enter official identity number',
                          prefixIcon: Iconsax.card,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          enabled: !tenantState.isLoading,
                          maxLength: 17,
                          counterText: '',
                          validator: GrihoValidators.optionalNid,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Iconsax.info_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isActive
                                  ? 'To end this lease or move the resident to a different unit, use "End Tenancy Agreement" on the Resident Details screen.'
                                  : 'To start a new active lease for this resident, use "Assign Unit & Start Tenancy" on the Resident Details screen.',
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
                      label: tenantState.isLoading
                          ? 'Saving Changes...'
                          : 'Save Tenant Changes',
                      icon: Iconsax.tick_circle,
                      isLoading: tenantState.isLoading,
                      onPressed: _updateTenant,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TenantHeaderCard extends StatelessWidget {
  final String name;
  final String phone;
  final TenantStatus status;

  const _TenantHeaderCard({
    required this.name,
    required this.phone,
    required this.status,
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
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              tenantInitials(name),
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TenantStatusChip(status: status),
        ],
      ),
    );
  }
}
