import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

class EditTenantScreen extends ConsumerStatefulWidget {
  final Tenant tenant;

  const EditTenantScreen({
    super.key,
    required this.tenant,
  });

  @override
  ConsumerState<EditTenantScreen> createState() =>
      _EditTenantScreenState();
}

class _EditTenantScreenState
    extends ConsumerState<EditTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _nidController;

  Property? _selectedProperty;
  Unit? _selectedUnit;

  late TenantStatus _status;

  @override
  void initState() {
    super.initState();

    final tenant = widget.tenant;

    _nameController = TextEditingController(
      text: tenant.name,
    );

    _phoneController = TextEditingController(
      text: tenant.phone,
    );

    _emailController = TextEditingController(
      text: tenant.email ?? '',
    );

    _nidController = TextEditingController(
      text: tenant.nidNumber ?? '',
    );

    _status = tenant.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();

    super.dispose();
  }

  Future<void> _updateTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;

    if (property == null || unit == null) {
      return;
    }

    final updatedTenant = widget.tenant.copyWith(
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
      final state = ref.read(
        tenantControllerProvider,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error?.toString() ??
                'Unable to update tenant.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(
      currentOwnerPropertiesProvider,
    );

    final tenantState = ref.watch(
      tenantControllerProvider,
    );

    final selectedPropertyId = _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
        : ref.watch(
      propertyUnitsProvider(
        selectedPropertyId,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Tenant',
        ),
      ),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          error: (error, stackTrace) {
            return _ErrorView(
              message:
              'Unable to load your properties.',
              onRetry: () {
                ref.invalidate(
                  currentOwnerPropertiesProvider,
                );
              },
            );
          },
          data: (properties) {
            if (properties.isEmpty) {
              return const Center(
                child: Text(
                  'No properties available.',
                ),
              );
            }

            if (_selectedProperty == null) {
              for (final property in properties) {
                if (property.id ==
                    widget.tenant.propertyId) {
                  _selectedProperty = property;
                  break;
                }
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenant Information',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Update the tenant information below.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // PROPERTY
                    // ==================================================

                    DropdownButtonFormField<Property>(
                      initialValue:
                      _selectedProperty,
                      decoration:
                      const InputDecoration(
                        labelText: 'Property',
                        border:
                        OutlineInputBorder(),
                      ),
                      items: properties.map(
                            (property) {
                          return DropdownMenuItem<
                              Property>(
                            value: property,
                            child: Text(
                              property.name,
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (property) {
                        setState(() {
                          _selectedProperty =
                              property;
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
                        'Property ID: '
                            '${_selectedProperty!.id}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // UNIT
                    // ==================================================

                    unitsAsync.when(
                      loading: () {
                        return const Padding(
                          padding:
                          EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Center(
                            child:
                            CircularProgressIndicator(),
                          ),
                        );
                      },
                      error: (error, stackTrace) {
                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Unable to load units.',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (_selectedProperty ==
                                    null) {
                                  return;
                                }

                                ref.invalidate(
                                  propertyUnitsProvider(
                                    _selectedProperty!
                                        .id,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.refresh,
                              ),
                              label:
                              const Text('Retry'),
                            ),
                          ],
                        );
                      },
                      data: (units) {
                        if (_selectedProperty ==
                            null) {
                          return const Text(
                            'Select a property first.',
                          );
                        }

                        if (units.isEmpty) {
                          return const Text(
                            'No units are available in this property.',
                          );
                        }

                        if (_selectedUnit == null) {
                          for (final unit in units) {
                            if (unit.id ==
                                widget.tenant.unitId) {
                              _selectedUnit = unit;
                              break;
                            }
                          }
                        }

                        return DropdownButtonFormField<Unit>(
                          initialValue:
                          _selectedUnit,
                          decoration:
                          const InputDecoration(
                            labelText: 'Unit',
                            border:
                            OutlineInputBorder(),
                          ),
                          items: units.map(
                                (unit) {
                              return DropdownMenuItem<
                                  Unit>(
                                value: unit,
                                child: Text(
                                  '${unit.unitNumber} — '
                                      'Floor ${unit.floorNumber}',
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ).toList(),
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
                      textCapitalization:
                      TextCapitalization.words,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Tenant Name',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ??
                            true) {
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
                      keyboardType:
                      TextInputType.phone,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Phone',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ??
                            true) {
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
                      keyboardType:
                      TextInputType.emailAddress,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NID
                    // ==================================================

                    TextFormField(
                      controller: _nidController,
                      keyboardType:
                      TextInputType.number,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'NID Number',
                        hintText: 'Optional',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // STATUS
                    // ==================================================

                    DropdownButtonFormField<TenantStatus>(
                      initialValue: _status,
                      decoration:
                      const InputDecoration(
                        labelText: 'Status',
                        border:
                        OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                          TenantStatus.active,
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value:
                          TenantStatus.inactive,
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (status) {
                        if (status == null) {
                          return;
                        }

                        setState(() {
                          _status = status;
                        });
                      },
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // UPDATE
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                        tenantState.isLoading
                            ? null
                            : _updateTenant,
                        child:
                        tenantState.isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Update Tenant',
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
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}