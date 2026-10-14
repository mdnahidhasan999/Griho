import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

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

  late TenantStatus _status;
  late String _phoneNumber;

  @override
  void initState() {
    super.initState();

    final tenant = widget.tenant;
    _nameController = TextEditingController(text: tenant.name);
    _emailController = TextEditingController(text: tenant.email ?? '');
    _nidController = TextEditingController(text: tenant.nidNumber ?? '');
    _status = tenant.status;
    _phoneNumber = tenant.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nidController.dispose();
    super.dispose();
  }

  // ============================================================
  // PHONE VALIDATION
  // ============================================================

  String? _getValidatedPhone() {
    final value = _phoneNumber.trim();

    if (!PhoneNumberUtils.isValid(value)) {
      return null;
    }

    return PhoneNumberUtils.normalize(value);
  }

  // ============================================================
  // UPDATE ACTION
  // ============================================================

  Future<void> _updateTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;

    if (property == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a property building.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (unit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a unit space.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final phone = _getValidatedPhone();
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid international phone number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedTenant = widget.tenant.copyWith(
      propertyId: property.id,
      unitId: unit.id,
      name: _nameController.text.trim(),
      phone: phone,
      email: _emailController.text
          .trim()
          .isEmpty
          ? null
          : _emailController.text.trim(),
      nidNumber: _nidController.text
          .trim()
          .isEmpty
          ? null
          : _nidController.text.trim(),
      status: _status,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error?.toString() ?? 'Unable to update tenant.'),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tenant record updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(result);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final tenantState = ref.watch(tenantControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Tenant',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorView(
                message: 'Unable to load properties.',
                onRetry: () {
                  ref.invalidate(currentOwnerPropertiesProvider);
                },
              ),
          data: (properties) {
            if (properties.isEmpty) {
              return const Center(child: Text('No properties available.'));
            }

            // Safe initial property match
            final initialProperty = properties
                .where((p) =>
            p.id == (_selectedProperty?.id ?? widget.tenant.propertyId))
                .firstOrNull ?? properties.first;

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
                    // Top Tenant Summary Card
                    _TenantHeaderCard(
                      name: _nameController.text
                          .trim()
                          .isNotEmpty
                          ? _nameController.text.trim()
                          : widget.tenant.name,
                      phone: _phoneNumber,
                      status: _status,
                    ),

                    const SizedBox(height: 18),

                    // Section 1: Property & Unit Allocation
                    _buildSectionCard(
                      title: '1. Allocation & Unit',
                      subtitle: 'Target building and residential unit assignment',
                      icon: Icons.apartment_rounded,
                      children: [
                        DropdownButtonFormField<Property>(
                          initialValue: _selectedProperty,
                          decoration: const InputDecoration(
                            labelText: 'Property Building',
                            prefixIcon: Icon(Icons.domain_rounded),
                            border: OutlineInputBorder(),
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
                          onChanged: tenantState.isLoading
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
                          error: (error, stackTrace) =>
                              Text(
                                'Unable to load units: $error',
                                style: TextStyle(
                                    color: theme.colorScheme.error),
                              ),
                          data: (units) {
                            if (_selectedProperty == null) {
                              return const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Assigned Unit',
                                  prefixIcon: Icon(
                                      Icons.door_front_door_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text('Select a property first'),
                              );
                            }

                            if (units.isEmpty) {
                              return const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Assigned Unit',
                                  prefixIcon: Icon(
                                      Icons.door_front_door_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                    'No units available in this property'),
                              );
                            }

                            final initialUnit = units
                                .where((u) =>
                            u.id == (_selectedUnit?.id ?? widget.tenant.unitId))
                                .firstOrNull;

                            _selectedUnit ??= initialUnit;

                            return DropdownButtonFormField<Unit>(
                              initialValue: units.contains(_selectedUnit)
                                  ? _selectedUnit
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Unit',
                                prefixIcon: Icon(
                                    Icons.door_front_door_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: units.map((unit) {
                                return DropdownMenuItem<Unit>(
                                  value: unit,
                                  child: Text(
                                    'Unit ${unit.unitNumber} • Floor ${unit
                                        .floorNumber}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: tenantState.isLoading
                                  ? null
                                  : (unit) {
                                setState(() {
                                  _selectedUnit = unit;
                                });
                              },
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

                    // Section 2: Contact & Identification
                    _buildSectionCard(
                      title: '2. Personal Credentials',
                      subtitle: 'Contact details and resident identity',
                      icon: Icons.contact_page_outlined,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          enabled: !tenantState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Full Legal Name',
                            hintText: 'Enter resident full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value
                                .trim()
                                .isEmpty) {
                              return 'Please enter tenant name.';
                            }
                            if (value
                                .trim()
                                .length < 2) {
                              return 'Name must be at least 2 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        IntlPhoneField(
                          initialValue: widget.tenant.phone,
                          enabled: !tenantState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Verified Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (phone) {
                            _phoneNumber = phone.completeNumber;
                          },
                          validator: (phone) {
                            if (phone == null || phone.completeNumber
                                .trim()
                                .isEmpty) {
                              return 'Please enter phone number.';
                            }
                            if (!PhoneNumberUtils.isValid(
                                phone.completeNumber)) {
                              return 'Please enter a valid international phone number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !tenantState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Email Address (Optional)',
                            hintText: 'e.g. tenant@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nidController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          enabled: !tenantState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'National ID / NID (Optional)',
                            hintText: 'Enter official identity number',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Section 3: Tenancy Lifecycle Status
                    _buildSectionCard(
                      title: '3. Lease & Status',
                      subtitle: 'Operational state of this tenancy agreement',
                      icon: Icons.toggle_on_outlined,
                      children: [
                        DropdownButtonFormField<TenantStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Tenancy Status',
                            prefixIcon: Icon(Icons.shield_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TenantStatus.active,
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.green, size: 18),
                                  SizedBox(width: 8),
                                  Text('Active Resident'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: TenantStatus.inactive,
                              child: Row(
                                children: [
                                  Icon(Icons.pause_circle_outline,
                                      color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Text('Inactive / Vacated'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: tenantState.isLoading
                              ? null
                              : (status) {
                            if (status == null) {
                              return;
                            }
                            setState(() {
                              _status = status;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          child: Text(
                            _status == TenantStatus.active
                                ? 'Active residents receive automated monthly rental bills and invoice statements.'
                                : 'Inactive residents will not be included when generating recurring monthly bills.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: tenantState.isLoading ? null : _updateTenant,
                        icon: tenantState.isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          tenantState.isLoading
                              ? 'Saving Changes...'
                              : 'Save Tenant Changes',
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
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
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
}

// ============================================================================
// HEADER PROFILE CARD
// ============================================================================

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
    final isActive = status == TenantStatus.active;

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
              _initials(name),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.green.shade800 : Colors.orange
                    .shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return 'T';
    }

    final parts = value
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
                Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
