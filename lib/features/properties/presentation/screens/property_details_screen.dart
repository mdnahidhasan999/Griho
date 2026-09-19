import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_arguments.dart';
import '../../../../app/router/route_names.dart';

import '../../../rents/domain/entities/rent_adjustment.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';

import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';

import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/property.dart';
import '../controllers/property_controller.dart';
import '../providers/current_owner_properties_provider.dart';
import '../providers/property_usecase_provider.dart';

class PropertyDetailsScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
  });

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends ConsumerState<PropertyDetailsScreen> {
  Property? _property;

  bool _isLoading = true;
  bool _isDeleting = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadProperty();
  }

  Future<void> _loadProperty() async {
    try {
      final getProperty = ref.read(getPropertyProvider);

      final property = await getProperty(widget.propertyId);

      if (!mounted) {
        return;
      }

      setState(() {
        _property = property;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _editProperty() async {
    final property = _property;

    if (property == null || _isDeleting) {
      return;
    }

    final route = RouteNames.editProperty.replaceFirst(
      ':propertyId',
      property.id,
    );

    final result = await context.push<Property>(
      route,
      extra: property,
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _property = result;
    });

    ref.invalidate(currentOwnerPropertiesProvider);

    ref.invalidate(propertyUnitsProvider(result.id));

    ref.invalidate(propertyTenantsProvider(result.id));

    await _loadProperty();
  }

  Future<void> _deleteProperty() async {
    final property = _property;

    if (property == null || _isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Property?'),
          content: Text(
            'Are you sure you want to delete '
                '"${property.name}"?\n\n'
                'This action cannot be undone.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final controller =
    ref.read(propertyControllerProvider.notifier);

    final success = await controller.deleteProperty(
      propertyId: property.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(currentOwnerPropertiesProvider);

      context.pop();

      return;
    }

    setState(() {
      _isDeleting = false;
    });

    final errorMessage = ref
        .read(propertyControllerProvider)
        .errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? 'Unable to delete property.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Property Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Property Details'),
        ),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadProperty,
        ),
      );
    }

    final property = _property;

    if (property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Property Details'),
        ),
        body: const _NotFoundView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Property',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isDeleting ? null : _editProperty,
          ),
          IconButton(
            tooltip: 'Delete Property',
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _deleteProperty,
          ),
        ],
      ),
      body: Stack(
        children: [
          _PropertyDetails(
            property: property,
          ),
          if (_isDeleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Deleting property...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PropertyDetails extends ConsumerWidget {
  final Property property;

  const _PropertyDetails({
    required this.property,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync =
    ref.watch(propertyUnitsProvider(property.id));

    final tenantsAsync =
    ref.watch(propertyTenantsProvider(property.id));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  property.name,
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _propertyTypeLabel(property.type),
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Property Information',
          children: [
            _InfoRow(
              label: 'Status',
              value: _propertyStatusLabel(property.status),
            ),
            _InfoRow(
              label: 'Number of Floors',
              value: property.numberOfFloors.toString(),
            ),
            _InfoRow(
              label: 'Address',
              value: property.address
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? property.address!
                  : 'Not provided',
            ),
            _InfoRow(
              label: 'Description',
              value: property.description
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? property.description!
                  : 'Not provided',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _UnitsSection(
          propertyId: property.id,
          propertyName: property.name,
          numberOfFloors: property.numberOfFloors,
          unitsAsync: unitsAsync,
        ),

        const SizedBox(height: 20),

        _TenantsSection(
          propertyId: property.id,
          propertyName: property.name,
          tenantsAsync: tenantsAsync,
        ),

        const SizedBox(height: 20),

        _PropertyRentManagementCard(
          property: property,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  String _propertyTypeLabel(PropertyType type) {
    switch (type) {
      case PropertyType.residential:
        return 'Residential';

      case PropertyType.commercial:
        return 'Commercial';

      case PropertyType.mixedUse:
        return 'Mixed Use';
    }
  }

  String _propertyStatusLabel(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.active:
        return 'Active';

      case PropertyStatus.inactive:
        return 'Inactive';
    }
  }
}

// ============================================================================
// PROPERTY RENT MANAGEMENT
// ============================================================================

// ============================================================================
// PROPERTY RENT MANAGEMENT
// ============================================================================

class _PropertyRentManagementCard extends ConsumerStatefulWidget {
  final Property property;

  const _PropertyRentManagementCard({
    required this.property,
  });

  @override
  ConsumerState<_PropertyRentManagementCard> createState() =>
      _PropertyRentManagementCardState();
}

class _PropertyRentManagementCardState
    extends ConsumerState<_PropertyRentManagementCard> {
  bool _isChanging = false;

  Future<void> _changePropertyRent() async {
    final result =
    await showDialog<_PropertyRentChangeResult>(
      context: context,
      builder: (dialogContext) {
        return const _PropertyRentAdjustmentDialog();
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await _submitPropertyRentChange(
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
    );
  }

  Future<void> _submitPropertyRentChange({
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    if (_isChanging) {
      return;
    }

    setState(() {
      _isChanging = true;
    });

    final controller =
    ref.read(rentRateControllerProvider.notifier);

    final rentRates =
    await controller.changePropertyRent(
      propertyId: widget.property.id,
      ownerId: widget.property.ownerId,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isChanging = false;
    });

    if (rentRates == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(
        error: (error,
            stackTrace,) =>
            error.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Unable to change property rent.',
          ),
        ),
      );

      return;
    }

    final action =
    adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Property rent $action by '
              '৳${_formatPropertyRentAmount(amount)} '
              'for ${rentRates.length} occupied unit(s).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rent Management',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Increase or decrease the rent for all '
                  'occupied units in this property.',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isChanging
                    ? null
                    : _changePropertyRent,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Adjust Property Rent',
                ),
              ),
            ),

            if (_isChanging) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROPERTY RENT ADJUSTMENT DIALOG
// ============================================================================

class _PropertyRentAdjustmentDialog extends StatefulWidget {
  const _PropertyRentAdjustmentDialog();

  @override
  State<_PropertyRentAdjustmentDialog> createState() =>
      _PropertyRentAdjustmentDialogState();
}

class _PropertyRentAdjustmentDialogState
    extends State<_PropertyRentAdjustmentDialog> {
  late final TextEditingController _amountController;

  DateTime _effectiveFrom = DateTime.now();

  RentAdjustmentType _adjustmentType =
      RentAdjustmentType.increase;

  @override
  void initState() {
    super.initState();

    _amountController =
        TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();

    super.dispose();
  }

  Future<void> _selectEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveFrom = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
    });
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid adjustment amount.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      _PropertyRentChangeResult(
        amount: amount,
        adjustmentType: _adjustmentType,
        effectiveFrom: _effectiveFrom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease =
        _adjustmentType ==
            RentAdjustmentType.increase;

    return AlertDialog(
      title: const Text(
        'Change Property Rent',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'This will adjust the rent for all '
                  'occupied units in this property.',
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------------
            // ADJUSTMENT TYPE
            // ----------------------------------------------------------

            Text(
              'Adjustment',
              style: Theme
                  .of(context)
                  .textTheme
                  .labelLarge,
            ),

            const SizedBox(height: 8),

            SegmentedButton<RentAdjustmentType>(
              segments: const [
                ButtonSegment<RentAdjustmentType>(
                  value:
                  RentAdjustmentType.increase,
                  icon: Icon(
                    Icons.arrow_upward,
                  ),
                  label: Text(
                    'Increase',
                  ),
                ),
                ButtonSegment<RentAdjustmentType>(
                  value:
                  RentAdjustmentType.decrease,
                  icon: Icon(
                    Icons.arrow_downward,
                  ),
                  label: Text(
                    'Decrease',
                  ),
                ),
              ],
              selected: {
                _adjustmentType,
              },
              onSelectionChanged:
                  (selection) {
                setState(() {
                  _adjustmentType =
                      selection.first;
                });
              },
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------------
            // ADJUSTMENT AMOUNT
            // ----------------------------------------------------------

            TextField(
              controller:
              _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration:
              const InputDecoration(
                labelText:
                'Adjustment Amount',
                hintText:
                'Example: 1000',
                prefixText: '৳ ',
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isIncrease
                  ? 'This amount will be added to each '
                  'occupied unit\'s current rent.'
                  : 'This amount will be deducted from each '
                  'occupied unit\'s current rent.',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodySmall,
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // EFFECTIVE FROM
            // ----------------------------------------------------------

            InkWell(
              borderRadius:
              BorderRadius.circular(12),
              onTap:
              _selectEffectiveDate,
              child: InputDecorator(
                decoration:
                const InputDecoration(
                  labelText:
                  'Effective From',
                  border:
                  OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_outlined,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        _formatPropertyRentDate(
                          _effectiveFrom,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // PREVIEW
            // ----------------------------------------------------------

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(12),
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius.circular(12),
                color: Theme
                    .of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIncrease
                        ? Icons.trending_up
                        : Icons.trending_down,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? 'Example: a unit with '
                          '৳12,000 rent will become '
                          '৳13,000 when the adjustment '
                          'is ৳1,000.'
                          : 'Example: a unit with '
                          '৳12,000 rent will become '
                          '৳11,000 when the adjustment '
                          'is ৳1,000.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Continue',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PROPERTY RENT CHANGE RESULT
// ============================================================================

class _PropertyRentChangeResult {
  final double amount;
  final RentAdjustmentType adjustmentType;
  final DateTime effectiveFrom;

  const _PropertyRentChangeResult({
    required this.amount,
    required this.adjustmentType,
    required this.effectiveFrom,
  });
}

String _formatPropertyRentDate(DateTime dateTime,) {
  final date = dateTime.toLocal();

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatPropertyRentAmount(double amount,) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}


class _UnitsSection extends ConsumerWidget {
  final String propertyId;
  final String propertyName;
  final int numberOfFloors;

  final AsyncValue<List<Unit>> unitsAsync;

  const _UnitsSection({
    required this.propertyId,
    required this.propertyName,
    required this.numberOfFloors,
    required this.unitsAsync,
  });

  Future<void> _openUnitList(BuildContext context,) async {
    await context.push(
      RouteNames.propertyUnits.replaceFirst(
        ':propertyId',
        propertyId,
      ),
      extra: PropertyUnitsRouteArguments(
        propertyName: propertyName,
        numberOfFloors: numberOfFloors,
      ),
    );
  }

  Future<void> _addUnit(BuildContext context,
      WidgetRef ref,) async {
    final result = await context.push<Unit>(
      RouteNames.addUnit.replaceFirst(
        ':propertyId',
        propertyId,
      ),
      extra: numberOfFloors,
    );

    if (!context.mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(
        propertyUnitsProvider(propertyId),
      );
    }
  }

  @override
  Widget build(BuildContext context,
      WidgetRef ref,) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Units',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _openUnitList(context);
                  },
                  child: const Text(
                    'View All',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            unitsAsync.when(
              loading: () {
                return const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                );
              },
              error: (error,
                  stackTrace,) {
                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load units.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(
                          propertyUnitsProvider(
                            propertyId,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Try Again',
                      ),
                    ),
                  ],
                );
              },
              data: (units) {
                if (units.isEmpty) {
                  return Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No units added yet.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          _addUnit(
                            context,
                            ref,
                          );
                        },
                        icon: const Icon(
                          Icons.add,
                        ),
                        label: const Text(
                          'Add Unit',
                        ),
                      ),
                    ],
                  );
                }

                final previewUnits =
                units.take(5).toList();

                return Column(
                  children: [
                    for (
                    int index = 0;
                    index <
                        previewUnits.length;
                    index++
                    ) ...[
                      _UnitCard(
                        unit:
                        previewUnits[index],
                      ),
                      if (index !=
                          previewUnits.length - 1)
                        const Divider(
                          height: 24,
                        ),
                    ],
                    if (units.length > 5) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment:
                        Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _openUnitList(
                              context,
                            );
                          },
                          child: Text(
                            'View all '
                                '${units.length} units',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Unit unit;

  const _UnitCard({
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 0,
      ),
      leading: const CircleAvatar(
        child: Icon(
          Icons.apartment_outlined,
        ),
      ),
      title: Text(
        unit.unitNumber,
        style: Theme
            .of(context)
            .textTheme
            .titleMedium,
      ),
      subtitle: Text(
        'Floor ${unit.floorNumber}',
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: () {
        context.push(
          RouteNames.unitDetails.replaceFirst(
            ':unitId',
            unit.id,
          ),
        );
      },
    );
  }
}

class _TenantsSection extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  final AsyncValue<List<Tenant>> tenantsAsync;

  const _TenantsSection({
    required this.propertyId,
    required this.propertyName,
    required this.tenantsAsync,
  });

  Future<void> _openTenantList(BuildContext context,) async {
    await context.push(
      RouteNames.propertyTenants.replaceFirst(
        ':propertyId',
        propertyId,
      ),
      extra: PropertyTenantsRouteArguments(
        propertyName: propertyName,
      ),
    );
  }

  Future<void> _addTenant(BuildContext context,
      WidgetRef ref,) async {
    await context.push(
      RouteNames.addTenant,
    );

    if (!context.mounted) {
      return;
    }

    ref.invalidate(
      propertyTenantsProvider(propertyId),
    );
  }

  @override
  Widget build(BuildContext context,
      WidgetRef ref,) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tenants',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _openTenantList(
                      context,
                    );
                  },
                  child: const Text(
                    'View All',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            tenantsAsync.when(
              loading: () {
                return const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                );
              },
              error: (error,
                  stackTrace,) {
                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load tenants.',
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      error.toString(),
                      style: TextStyle(
                        color: Theme
                            .of(context)
                            .colorScheme
                            .error,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      stackTrace.toString(),
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(
                          propertyTenantsProvider(
                            propertyId,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Try Again',
                      ),
                    ),
                  ],
                );
              },
              data: (tenants) {
                if (tenants.isEmpty) {
                  return Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No tenants added yet.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          _addTenant(
                            context,
                            ref,
                          );
                        },
                        icon: const Icon(
                          Icons.person_add_alt_1,
                        ),
                        label: const Text(
                          'Add Tenant',
                        ),
                      ),
                    ],
                  );
                }

                final previewTenants =
                tenants.take(5).toList();

                return Column(
                  children: [
                    for (
                    int index = 0;
                    index <
                        previewTenants.length;
                    index++
                    ) ...[
                      _TenantPreviewCard(
                        tenant:
                        previewTenants[index],
                      ),
                      if (index !=
                          previewTenants.length - 1)
                        const Divider(
                          height: 24,
                        ),
                    ],
                    if (tenants.length > 5) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment:
                        Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _openTenantList(
                              context,
                            );
                          },
                          child: Text(
                            'View all '
                                '${tenants.length} tenants',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantPreviewCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantPreviewCard({
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 0,
      ),
      leading: const CircleAvatar(
        child: Icon(
          Icons.person_outline,
        ),
      ),
      title: Text(
        tenant.name,
        style: Theme
            .of(context)
            .textTheme
            .titleMedium,
      ),
      subtitle: Text(
        tenant.phone,
      ),
      trailing: _TenantStatusChip(
        status: tenant.status,
      ),
    );
  }
}

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        color: Theme
            .of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        _statusLabel(status),
        style: Theme
            .of(context)
            .textTheme
            .labelSmall,
      ),
    );
  }

  String _statusLabel(TenantStatus status,) {
    switch (status) {
      case TenantStatus.active:
        return 'Active';

      case TenantStatus.inactive:
        return 'Inactive';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium,
          ),
        ],
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
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding:
        EdgeInsets.all(24),
        child: Text(
          'Property not found.',
          textAlign:
          TextAlign.center,
        ),
      ),
    );
  }
}