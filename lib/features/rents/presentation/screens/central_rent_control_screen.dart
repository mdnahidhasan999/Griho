// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../providers/rent_rate_provider.dart';
import '../widgets/rent_ui_helpers.dart';

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
    if (_isSubmitting) {
      return;
    }
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

  String _floorLabel(int floor) => switch (floor) {
    1 => '1st Floor',
    2 => '2nd Floor',
    3 => '3rd Floor',
    _ => 'Floor $floor',
  };

  String _unitStatusText(Unit unit) => switch (unit.status) {
    UnitStatus.occupied => 'Occupied',
    UnitStatus.available => 'Vacant',
    _ =>
      unit.status.name.isNotEmpty
          ? unit.status.name[0].toUpperCase() + unit.status.name.substring(1)
          : 'Other',
  };

  Future<void> _applyBulkAdjustment(
    Property property,
    int effectiveFloor,
  ) async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final controller = ref.read(rentRateControllerProvider.notifier);
      List<RentRate>? updatedList;

      if (_scope == _RentTargetScope.property) {
        updatedList = await controller.changePropertyRent(
          propertyId: property.id,
          ownerId: property.ownerId,
          amount: amount,
          adjustmentType: _adjustmentType,
          effectiveFrom: _effectiveDate,
        );
      } else if (_scope == _RentTargetScope.floor) {
        updatedList = await controller.changeFloorRent(
          propertyId: property.id,
          floorNumber: effectiveFloor,
          ownerId: property.ownerId,
          amount: amount,
          adjustmentType: _adjustmentType,
          effectiveFrom: _effectiveDate,
        );
      }

      if (!mounted) {
        return;
      }

      if (updatedList == null) {
        final err = ref
            .read(rentRateControllerProvider)
            .whenOrNull(error: (e, _) => e.toString());
        throw StateError(err ?? 'Failed to update rent rates.');
      }

      for (final rate in updatedList) {
        ref.invalidate(
          currentRentRateProvider((unitId: rate.unitId, ownerId: rate.ownerId)),
        );
        ref.invalidate(
          unitRentRateHistoryProvider((
            unitId: rate.unitId,
            ownerId: rate.ownerId,
          )),
        );
      }

      final actionText = _adjustmentType == RentAdjustmentType.increase
          ? 'increased'
          : 'decreased';

      await AuditLoggerService.log(
        ownerId: property.ownerId,
        propertyId: property.id,
        propertyName: property.name,
        category: 'rent',
        actionTitle: _scope == _RentTargetScope.property
            ? 'Property-Wide Rent Adjusted'
            : 'Floor $effectiveFloor Rent Adjusted',
        details:
            'Monthly rent $actionText by ৳${formatRentAmount(amount)} across ${updatedList.length} unit(s).',
      );

      if (!mounted) {
        return;
      }

      GrihoFeedback.showSuccess(
        context,
        'Rent $actionText by ৳${formatRentAmount(amount)} for ${updatedList.length} unit(s).',
      );

      _amountController.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        e.toString().replaceFirst('Bad state: ', ''),
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
      appBar: AppBar(title: const Text('Rent & Tariff Control')),
      body: propertiesAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading buildings...'),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load properties',
              subtitle: err.toString(),
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
                  subtitle: 'Add a property first to manage rent tariffs.',
                ),
              ),
            );
          }

          final property =
              (_selectedProperty != null &&
                  properties.any((p) => p.id == _selectedProperty!.id))
              ? _selectedProperty!
              : properties.first;

          final floors = List<int>.generate(
            property.numberOfFloors > 0 ? property.numberOfFloors : 1,
            (i) => i + 1,
          );
          final effectiveFloor =
              (_selectedFloor != null && floors.contains(_selectedFloor))
              ? _selectedFloor!
              : floors.first;

          // Watch units only when the user actually selects the Unit scope to avoid extra Firestore reads.
          final unitsAsync = _scope == _RentTargetScope.unit
              ? ref.watch(propertyUnitsProvider(property.id))
              : null;

          final loadedUnits = unitsAsync?.value ?? const <Unit>[];
          final effectiveUnit = loadedUnits.isEmpty
              ? null
              : (_selectedUnit != null &&
                    loadedUnits.any((u) => u.id == _selectedUnit!.id))
              ? _selectedUnit!
              : loadedUnits.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrihoSectionCard(
                    title: '1. Select Operation Scope',
                    subtitle:
                        'Choose whether to adjust rent for a whole building, a specific floor, or manage a single unit.',
                    icon: Iconsax.setting_4,
                    children: [
                      SegmentedButton<_RentTargetScope>(
                        segments: const [
                          ButtonSegment(
                            value: _RentTargetScope.property,
                            label: Text('Property'),
                            icon: Icon(Iconsax.buildings_2, size: 16),
                          ),
                          ButtonSegment(
                            value: _RentTargetScope.floor,
                            label: Text('Floor'),
                            icon: Icon(Iconsax.layer, size: 16),
                          ),
                          ButtonSegment(
                            value: _RentTargetScope.unit,
                            label: Text('Unit'),
                            icon: Icon(Iconsax.home_2, size: 16),
                          ),
                        ],
                        selected: {_scope},
                        onSelectionChanged: _isSubmitting
                            ? null
                            : (s) => setState(() => _scope = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GrihoSectionCard(
                    title: '2. Choose Target Location',
                    icon: Iconsax.location,
                    children: [
                      GrihoPickerField<Property>(
                        label: 'Select Building',
                        hint: 'Choose a building',
                        sheetTitle: 'Select Building',
                        searchHint: 'Search by building name or code...',
                        icon: Iconsax.buildings_2,
                        items: properties,
                        value: property,
                        enabled: !_isSubmitting,
                        itemTitle: (p) => p.name,
                        itemSubtitle: (p) => p.propertyCode.trim().isNotEmpty
                            ? 'Code: ${p.propertyCode}'
                            : null,
                        onChanged: (val) {
                          setState(() {
                            _selectedProperty = val;
                            _selectedFloor = 1;
                            _selectedUnit = null;
                          });
                        },
                      ),
                      if (_scope == _RentTargetScope.floor) ...[
                        const SizedBox(height: 14),
                        GrihoPickerField<int>(
                          key: ValueKey('floor_${property.id}'),
                          label: 'Select Floor Level',
                          hint: 'Choose a floor',
                          sheetTitle: 'Select Floor Level',
                          searchHint: 'Search floor...',
                          icon: Iconsax.layer,
                          items: floors,
                          value: effectiveFloor,
                          enabled: !_isSubmitting,
                          itemTitle: _floorLabel,
                          onChanged: (val) =>
                              setState(() => _selectedFloor = val),
                        ),
                      ],
                      if (_scope == _RentTargetScope.unit &&
                          unitsAsync != null) ...[
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

                            return GrihoPickerField<Unit>(
                              key: ValueKey('unit_${property.id}'),
                              label: 'Select Unit Space',
                              hint: 'Choose a unit',
                              sheetTitle: 'Select Unit Space',
                              searchHint: 'Search by unit or floor...',
                              icon: Iconsax.home_2,
                              items: units,
                              value: effectiveUnit,
                              enabled: !_isSubmitting,
                              itemTitle: (u) => 'Unit ${u.unitNumber}',
                              itemSubtitle: (u) {
                                final custom = u.name?.trim() ?? '';
                                final base =
                                    '${_floorLabel(u.floorNumber)} • ${_unitStatusText(u)}';
                                return custom.isNotEmpty
                                    ? '$custom • $base'
                                    : base;
                              },
                              onChanged: (val) =>
                                  setState(() => _selectedUnit = val),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_scope != _RentTargetScope.unit) ...[
                    GrihoSectionCard(
                      title: '3. Bulk Adjustment Parameters',
                      icon: Iconsax.money_change,
                      children: [
                        SegmentedButton<RentAdjustmentType>(
                          segments: const [
                            ButtonSegment(
                              value: RentAdjustmentType.increase,
                              icon: Icon(Iconsax.trend_up, size: 17),
                              label: Text('Increase Rent'),
                            ),
                            ButtonSegment(
                              value: RentAdjustmentType.decrease,
                              icon: Icon(Iconsax.trend_down, size: 17),
                              label: Text('Decrease Rent'),
                            ),
                          ],
                          selected: {_adjustmentType},
                          onSelectionChanged: _isSubmitting
                              ? null
                              : (s) =>
                                    setState(() => _adjustmentType = s.first),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          enabled: !_isSubmitting,
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
                          ),
                          validator: (val) {
                            if (_scope == _RentTargetScope.unit) {
                              return null;
                            }
                            final amt = double.tryParse(val?.trim() ?? '');
                            if (amt == null || !amt.isFinite || amt <= 0) {
                              return 'Enter a valid amount greater than 0.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isSubmitting ? null : _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Effective From Date',
                              prefixIcon: Icon(
                                Iconsax.calendar_1,
                                color: GrihoColors.emerald,
                                size: 20,
                              ),
                              suffixIcon: Icon(Iconsax.arrow_right_3, size: 16),
                            ),
                            child: Text(
                              formatRentDate(_effectiveDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GrihoPrimaryButton(
                      label: _scope == _RentTargetScope.property
                          ? 'Apply Property-Wide Rent Adjustment'
                          : 'Apply Floor-Wide Rent Adjustment',
                      icon: Iconsax.tick_circle,
                      isLoading: _isSubmitting,
                      onPressed: () =>
                          _applyBulkAdjustment(property, effectiveFloor),
                    ),
                  ],
                  if (_scope == _RentTargetScope.unit &&
                      effectiveUnit != null) ...[
                    GrihoSectionCard(
                      title: '3. Unit ${effectiveUnit.unitNumber} Operations',
                      subtitle:
                          'Manage monthly rent invoices, update unit rent rate, or inspect historical rate changes.',
                      icon: Iconsax.wallet_check,
                      children: [
                        GrihoPrimaryButton(
                          label: 'Monthly Rent Invoices (Generate & View)',
                          icon: Iconsax.receipt_item,
                          onPressed: () {
                            context.push(
                              RouteNames.unitMonthlyRent.replaceFirst(
                                ':unitId',
                                effectiveUnit.id,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              context.push(
                                RouteNames.changeUnitRent.replaceFirst(
                                  ':unitId',
                                  effectiveUnit.id,
                                ),
                              );
                            },
                            icon: const Icon(Iconsax.edit_2, size: 18),
                            label: const Text(
                              'Update Unit Monthly Rent Rate',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GrihoSecondaryButton(
                          label: 'View Rate Adjustment History',
                          icon: Iconsax.clock,
                          onPressed: () {
                            context.push(
                              RouteNames.unitRentRateHistory.replaceFirst(
                                ':unitId',
                                effectiveUnit.id,
                              ),
                            );
                          },
                        ),
                      ],
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
