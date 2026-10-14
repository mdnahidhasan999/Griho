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
        body: _buildIneligibleView(
          context,
          icon: Icons.cancel_outlined,
          title: 'Tenant is Already Active',
          message:
          'This tenant currently has an active tenancy. A new tenancy agreement can only be initiated for inactive or vacated tenants.',
        ),
      );
    }

    if (tenant.accountStatus != TenantAccountStatus.registered) {
      return Scaffold(
        appBar: AppBar(title: const Text('Start New Tenancy')),
        body: _buildIneligibleView(
          context,
          icon: Icons.person_outline_rounded,
          title: 'Account Not Registered',
          message:
          'The tenant must register their personal Griho account before an official tenancy agreement can be initiated.',
        ),
      );
    }

    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      backgroundColor: Theme
          .of(context)
          .colorScheme
          .surface,
      appBar: AppBar(
        title: const Text(
          'Start New Tenancy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorView(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tenant Identity Card
              _buildTenantHeaderCard(tenant),

              const SizedBox(height: 18),

              // Section 1: Property Selection
              _buildSectionCard(
                title: '1. Select Property',
                subtitle: 'Choose an active building for the new lease',
                icon: Icons.apartment_rounded,
                children: [
                  if (properties.isEmpty)
                    const _EmptyState(
                      icon: Icons.apartment_outlined,
                      message: 'No active properties are available.',
                    )
                  else
                    _buildPropertyDropdown(properties),
                ],
              ),

              const SizedBox(height: 18),

              // Section 2: Unit Selection
              if (selectedProperty != null) ...[
                _buildSectionCard(
                  title: '2. Select Available Unit',
                  subtitle: 'Pick a vacant apartment or commercial space',
                  icon: Icons.door_front_door_outlined,
                  children: [
                    _buildUnitSection(selectedProperty),
                  ],
                ),
                const SizedBox(height: 18),

                // Section 3: Financial Rent Terms
                _buildSectionCard(
                  title: '3. Rental Agreement',
                  subtitle: 'Specify recurring monthly rent amount',
                  icon: Icons.payments_outlined,
                  children: [
                    _buildRentInput(),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _canSubmit(selectedProperty: selectedProperty)
                      ? () =>
                      _confirmStartNewTenancy(property: selectedProperty!)
                      : null,
                  icon: _isSubmitting
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
                    _isSubmitting ? 'Starting Tenancy...' : 'Start New Tenancy',
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
              _initials(tenant.name),
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
                      Icons.phone_outlined,
                      size: 14,
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
                        Icons.mail_outline_rounded,
                        size: 14,
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
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 12,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Registered User',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Inactive / Vacated',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildPropertyDropdown(List<Property> properties) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPropertyId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Target Property',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.domain_rounded),
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
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: Theme
                      .of(context)
                      .colorScheme
                      .onSurfaceVariant,
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
      loading: () =>
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) =>
          _ErrorView(
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
            message: 'No available units found in this property.',
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
        final selected = units
            .where((u) => u.id == unitId)
            .firstOrNull;
        if (selected != null) {
          setState(() {
            _selectedUnit = selected;
          });
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
                  alpha: 0.35),
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
                    : () {
                  setState(() {
                    _selectedUnit = unit;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: unit.id,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.name
                                  ?.trim()
                                  .isNotEmpty == true
                                  ? unit.name!
                                  : 'Unit ${unit.unitNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unit ${unit.unitNumber} • Floor ${unit
                                  .floorNumber}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Vacant',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
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
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.currency_exchange_rounded),
      ),
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
    final unit = _selectedUnit;
    if (unit == null) {
      return;
    }

    final amount = _getRentAmount();
    if (amount == null) {
      _showMessage('Please enter a valid monthly rent amount.');
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
                'Start a new active tenancy for ${widget.tenant
                    .name} in ${property.name}, Unit ${unit.unitNumber}?',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5),
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
                      _formatRent(amount),
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
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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

  Widget _buildIneligibleView(BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatRent(double rent) {
    if (rent == rent.roundToDouble()) {
      return '৳${rent.toStringAsFixed(0)} / month';
    }
    return '৳${rent.toStringAsFixed(2)} / month';
  }

  static String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return 'T';
    }

    final parts =
    value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
