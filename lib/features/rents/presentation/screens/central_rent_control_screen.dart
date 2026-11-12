import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../providers/rent_rate_provider.dart';

enum _RentTargetScope { property, floor, unit }

class CentralRentControlScreen extends ConsumerStatefulWidget {
  const CentralRentControlScreen({super.key});

  @override
  ConsumerState<CentralRentControlScreen> createState() =>
      _CentralRentControlScreenState();
}

class _CentralRentControlScreenState
    extends ConsumerState<CentralRentControlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  _RentTargetScope _scope = _RentTargetScope.property;
  RentAdjustmentType _adjustmentType = RentAdjustmentType.increase;

  Property? _selectedProperty;
  int? _selectedFloor;
  Unit? _selectedUnit;
  DateTime _effectiveDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _effectiveDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _applyRentAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final property = _selectedProperty;
    if (property == null) return;

    if (_scope == _RentTargetScope.unit && _selectedUnit != null) {
      // নির্দিষ্ট ইউনিটের জন্য সরাসরি আপনার বিদ্যমান ChangeUnitRentScreen-এ পাঠানো সবচেয়ে নিরাপদ
      await context.push(
        RouteNames.changeUnitRent.replaceFirst(':unitId', _selectedUnit!.id),
      );
      if (mounted) {
        ref.invalidate(
          currentRentRateProvider((
            unitId: _selectedUnit!.id,
            ownerId: property.ownerId,
          )),
        );
      }
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final controller = ref.read(rentRateControllerProvider.notifier);
      List<dynamic>? updatedList;

      if (_scope == _RentTargetScope.property) {
        updatedList = await controller.changePropertyRent(
          propertyId: property.id,
          ownerId: property.ownerId,
          amount: amount,
          adjustmentType: _adjustmentType,
          effectiveFrom: _effectiveDate,
        );
      } else if (_scope == _RentTargetScope.floor && _selectedFloor != null) {
        updatedList = await controller.changeFloorRent(
          propertyId: property.id,
          floorNumber: _selectedFloor!,
          ownerId: property.ownerId,
          amount: amount,
          adjustmentType: _adjustmentType,
          effectiveFrom: _effectiveDate,
        );
      }

      if (!mounted) return;

      if (updatedList == null) {
        final err = ref
            .read(rentRateControllerProvider)
            .whenOrNull(error: (e, _) => e.toString());
        throw StateError(err ?? 'Failed to update rent rates.');
      }

      final actionText = _adjustmentType == RentAdjustmentType.increase
          ? 'increased'
          : 'decreased';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rent $actionText by ৳${amount.toStringAsFixed(0)} for ${updatedList.length} occupied unit(s).',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _amountController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Rent & Tariff Control',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading properties: $err')),
        data: (properties) {
          if (properties.isEmpty) {
            return const Center(
              child: Text('No properties available to manage rent.'),
            );
          }

          _selectedProperty ??= properties.first;
          final property = _selectedProperty!;
          final unitsAsync = ref.watch(propertyUnitsProvider(property.id));

          final floors = List<int>.generate(
            property.numberOfFloors > 0 ? property.numberOfFloors : 1,
            (i) => i + 1,
          );
          if (_selectedFloor == null || !floors.contains(_selectedFloor)) {
            _selectedFloor = floors.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Scope Selector Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Select Adjustment Scope',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<_RentTargetScope>(
                          segments: const [
                            ButtonSegment(
                              value: _RentTargetScope.property,
                              label: Text('Property'),
                              icon: Icon(Icons.apartment_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: _RentTargetScope.floor,
                              label: Text('Floor'),
                              icon: Icon(Icons.layers_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: _RentTargetScope.unit,
                              label: Text('Unit'),
                              icon: Icon(
                                Icons.door_front_door_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                          selected: {_scope},
                          onSelectionChanged: (s) {
                            setState(() {
                              _scope = s.first;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Target Perimeter Selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. Choose Target Location',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<Property>(
                          initialValue: property,
                          decoration: const InputDecoration(
                            labelText: 'Select Building',
                            prefixIcon: Icon(Icons.domain_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: properties
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.name} (${p.propertyCode})'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedProperty = val;
                                _selectedFloor = 1;
                                _selectedUnit = null;
                              });
                            }
                          },
                        ),
                        if (_scope == _RentTargetScope.floor) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedFloor,
                            decoration: const InputDecoration(
                              labelText: 'Select Floor Level',
                              prefixIcon: Icon(Icons.layers_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: floors
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text('Floor $f'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedFloor = val);
                            },
                          ),
                        ],
                        if (_scope == _RentTargetScope.unit) ...[
                          const SizedBox(height: 14),
                          unitsAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error loading units: $e'),
                            data: (units) {
                              if (units.isEmpty) {
                                return const Text(
                                  'No units configured in this building.',
                                );
                              }
                              if (_selectedUnit == null ||
                                  !units.any(
                                    (u) => u.id == _selectedUnit!.id,
                                  )) {
                                _selectedUnit = units.first;
                              }

                              return DropdownButtonFormField<Unit>(
                                initialValue: _selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Select Unit Space',
                                  prefixIcon: Icon(Icons.meeting_room_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: units
                                    .map(
                                      (u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                          'Unit ${u.unitNumber} (Floor ${u.floorNumber}) • ${u.status == UnitStatus.occupied ? "Occupied" : "Vacant"}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => _selectedUnit = val);
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Adjustment Parameters (For Property & Floor Bulk Updates)
                  if (_scope != _RentTargetScope.unit)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Adjustment Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SegmentedButton<RentAdjustmentType>(
                            segments: const [
                              ButtonSegment(
                                value: RentAdjustmentType.increase,
                                icon: Icon(Icons.trending_up_rounded),
                                label: Text('Increase Rent'),
                              ),
                              ButtonSegment(
                                value: RentAdjustmentType.decrease,
                                icon: Icon(Icons.trending_down_rounded),
                                label: Text('Decrease Rent'),
                              ),
                            ],
                            selected: {_adjustmentType},
                            onSelectionChanged: (s) {
                              setState(() => _adjustmentType = s.first);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Adjustment Amount (per unit)',
                              hintText: 'e.g. 500',
                              prefixText: '৳ ',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (_scope == _RentTargetScope.unit) return null;
                              final amt = double.tryParse(val?.trim() ?? '');
                              if (amt == null || amt <= 0) {
                                return 'Enter a valid amount greater than 0.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Effective From Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${_effectiveDate.day.toString().padLeft(2, '0')}/${_effectiveDate.month.toString().padLeft(2, '0')}/${_effectiveDate.year}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _applyRentAdjustment,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _scope == _RentTargetScope.unit
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                      label: Text(
                        _scope == _RentTargetScope.unit
                            ? 'Proceed to Unit Rent Editor'
                            : 'Apply Bulk Rent Adjustment',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  if (_scope == _RentTargetScope.unit &&
                      _selectedUnit != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          RouteNames.unitRentRateHistory.replaceFirst(
                            ':unitId',
                            _selectedUnit!.id,
                          ),
                        );
                      },
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('View Selected Unit Rent History'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
