import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

class StartNewTenancyScreen extends ConsumerStatefulWidget {
  final Tenant tenant;

  const StartNewTenancyScreen({super.key, required this.tenant});

  @override
  ConsumerState<StartNewTenancyScreen> createState() =>
      _StartNewTenancyScreenState();
}

class _StartNewTenancyScreenState extends ConsumerState<StartNewTenancyScreen> {
  String? _selectedPropertyId;
  Unit? _selectedUnit;

  final TextEditingController _rentController = TextEditingController();

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
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only an inactive tenant can start a new tenancy.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (tenant.accountStatus != TenantAccountStatus.registered) {
      return Scaffold(
        appBar: AppBar(title: const Text('Start New Tenancy')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The tenant account must be registered before starting a new tenancy.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Start New Tenancy')),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(currentOwnerPropertiesProvider);
          },
        ),
        data: (properties) {
          final activeProperties = properties
              .where((property) => property.status == PropertyStatus.active)
              .toList();

          if (_selectedPropertyId != null &&
              !activeProperties.any(
                (property) => property.id == _selectedPropertyId,
              )) {
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTenantCard(tenant),

            const SizedBox(height: 24),

            Text(
              'Select Property',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            if (properties.isEmpty)
              const _EmptyState(
                icon: Icons.apartment_outlined,
                message: 'No active properties are available.',
              )
            else
              _buildPropertyDropdown(properties),

            const SizedBox(height: 24),

            if (selectedProperty != null) ...[
              Text(
                'Select Available Unit',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              _buildUnitSection(selectedProperty),

              const SizedBox(height: 24),

              _buildRentInput(),
            ],

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _canSubmit(selectedProperty: selectedProperty)
                  ? () => _confirmStartNewTenancy(property: selectedProperty!)
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start New Tenancy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard(Tenant tenant) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tenant.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(tenant.phone),
            if (tenant.email != null) ...[
              const SizedBox(height: 4),
              Text(tenant.email!),
            ],
            const SizedBox(height: 12),
            const Chip(
              avatar: Icon(Icons.person_outline, size: 18),
              label: Text('Registered Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDropdown(List<Property> properties) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPropertyId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Property',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.apartment_outlined),
      ),
      hint: const Text('Select a property'),
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
                ),
              ),
              const SizedBox(width: 8),
              Text(
                property.propertyCode,
                style: Theme.of(context).textTheme.bodySmall,
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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _ErrorView(
        message: error.toString(),
        onRetry: () {
          ref.invalidate(propertyUnitsProvider(propertyId));
        },
      ),
      data: (units) {
        final availableUnits = units
            .where((unit) => unit.status == UnitStatus.available)
            .toList();

        if (availableUnits.isEmpty) {
          return const _EmptyState(
            icon: Icons.meeting_room_outlined,
            message: 'No available units in this property.',
          );
        }

        return _buildUnitList(availableUnits);
      },
    );
  }

  Widget _buildUnitList(List<Unit> units) {
    return RadioGroup<String>(
      groupValue: _selectedUnit?.id,
      onChanged: (unitId) {
        if (_isSubmitting || unitId == null) {
          return;
        }

        final selectedUnit = units.firstWhere((unit) => unit.id == unitId);

        setState(() {
          _selectedUnit = selectedUnit;
        });
      },
      child: Column(
        children: units.map((unit) {
          final isSelected = _selectedUnit?.id == unit.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: RadioListTile<String>(
                value: unit.id,
                title: Text(
                  unit.name?.trim().isNotEmpty == true
                      ? unit.name!
                      : 'Unit ${unit.unitNumber}',
                ),
                subtitle: Text(
                  'Unit ${unit.unitNumber} • '
                  'Floor ${unit.floorNumber}',
                ),
                selected: isSelected,
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
        hintText: 'Enter monthly rent',
        prefixText: '৳ ',
        suffixText: '/month',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.payments_outlined),
      ),
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
    final unit = _selectedUnit;

    if (unit == null) {
      return;
    }

    final amount = _getRentAmount();

    if (amount == null) {
      _showMessage('Please enter a valid monthly rent amount.');
      return;
    }

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
                'Start a new tenancy for '
                '${widget.tenant.name} '
                'in ${property.name}, '
                'Unit ${unit.unitNumber}?',
              ),
              const SizedBox(height: 16),
              Text(
                'Initial Monthly Rent',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatRent(amount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
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
    setState(() {
      _isSubmitting = true;
    });

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

    setState(() {
      _isSubmitting = false;
    });

    if (startedTenant == null) {
      final state = ref.read(tenantControllerProvider);

      _showMessage(state.error?.toString() ?? 'Unable to start new tenancy.');

      return;
    }

    ref.invalidate(currentOwnerPropertiesProvider);

    ref.invalidate(propertyUnitsProvider(property.id));

    _showMessage('New tenancy started successfully.');

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRent(double rent) {
    return '৳${rent.toStringAsFixed(0)}/month';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
