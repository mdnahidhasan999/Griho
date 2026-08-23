import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/create_tenant_request.dart';
import '../controllers/tenant_controller.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({super.key});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();

  Property? _selectedProperty;
  Unit? _selectedUnit;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();

    super.dispose();
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;

    if (property == null || unit == null) {
      return;
    }

    final request = CreateTenantRequest(
      userId: null,
      propertyId: property.id,
      unitId: unit.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      nidNumber: _nidController.text.trim().isEmpty
          ? null
          : _nidController.text.trim(),
    );

    final tenant = await ref
        .read(tenantControllerProvider.notifier)
        .createTenant(request);

    if (!mounted) {
      return;
    }

    if (tenant == null) {
      final state = ref.read(tenantControllerProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error?.toString() ?? 'Unable to create tenant.'),
        ),
      );

      return;
    }

    Navigator.of(context).pop(tenant);
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    final tenantState = ref.watch(tenantControllerProvider);

    final selectedPropertyId = _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
        : ref.watch(propertyUnitsProvider(selectedPropertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Add Tenant')),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return _ErrorView(
              message: 'Unable to load your properties.',
              onRetry: () {
                ref.invalidate(currentOwnerPropertiesProvider);
              },
            );
          },
          data: (properties) {
            if (properties.isEmpty) {
              return const _NoPropertyView();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenant Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Select a property and unit, then enter the tenant information.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // PROPERTY
                    // ==================================================
                    DropdownButtonFormField<Property>(
                      initialValue: _selectedProperty,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        border: OutlineInputBorder(),
                      ),
                      items: properties.map((property) {
                        return DropdownMenuItem<Property>(
                          value: property,
                          child: Text(
                            property.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (property) {
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

                    const SizedBox(height: 8),

                    if (_selectedProperty != null)
                      Text(
                        'Property ID: ${_selectedProperty!.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // UNIT
                    // ==================================================
                    unitsAsync.when(
                      loading: () {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      error: (error, stackTrace) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unable to load units.'),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (_selectedProperty == null) {
                                  return;
                                }

                                ref.invalidate(
                                  propertyUnitsProvider(_selectedProperty!.id),
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        );
                      },
                      data: (units) {
                        if (_selectedProperty == null) {
                          return const Text('Select a property first.');
                        }

                        if (units.isEmpty) {
                          return const Text(
                            'No units are available in this property.',
                          );
                        }

                        return DropdownButtonFormField<Unit>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: units.map((unit) {
                            return DropdownMenuItem<Unit>(
                              value: unit,
                              child: Text(
                                '${unit.unitNumber} — Floor ${unit.floorNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (unit) {
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

                    const SizedBox(height: 28),

                    // ==================================================
                    // NAME
                    // ==================================================
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tenant Name',
                        hintText: 'e.g. Rahim Uddin',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter tenant name.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // PHONE
                    // ==================================================
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: 'e.g. 017XXXXXXXX',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter phone number.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // EMAIL
                    // ==================================================
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NID
                    // ==================================================
                    TextFormField(
                      controller: _nidController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'NID Number',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: tenantState.isLoading ? null : _createTenant,
                        child: tenantState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Add Tenant'),
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
}

class _NoPropertyView extends StatelessWidget {
  const _NoPropertyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'You need to add a property before adding a tenant.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

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
            const Icon(Icons.error_outline, size: 48),
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
