// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../domain/entities/create_unit_request.dart';
import '../controllers/unit_controller.dart';
import '../widgets/unit_ui_helpers.dart';

class AddUnitScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final int numberOfFloors;

  const AddUnitScreen({
    super.key,
    required this.propertyId,
    required this.numberOfFloors,
  });

  @override
  ConsumerState<AddUnitScreen> createState() => _AddUnitScreenState();
}

class _AddUnitScreenState extends ConsumerState<AddUnitScreen> {
  final _formKey = GlobalKey<FormState>();

  final _unitNumberController = TextEditingController();
  final _nameController = TextEditingController();

  int? _selectedFloor = 1;

  @override
  void dispose() {
    _unitNumberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createUnit() async {
    FocusScope.of(context).unfocus();
    if (ref.read(unitControllerProvider).isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final floor = _selectedFloor;
    if (floor == null) {
      GrihoFeedback.showError(context, 'Please select a valid floor level.');
      return;
    }

    final unitNumber = _unitNumberController.text.trim();
    final name = _nameController.text.trim();

    final request = CreateUnitRequest(
      propertyId: widget.propertyId,
      floorNumber: floor,
      unitNumber: unitNumber,
      name: name.isEmpty ? null : name,
    );

    final unit = await ref
        .read(unitControllerProvider.notifier)
        .createUnit(request: request);

    if (!mounted) {
      return;
    }

    if (unit == null) {
      final state = ref.read(unitControllerProvider);
      GrihoFeedback.showError(
        context,
        state.errorMessage ?? 'Unable to create unit.',
      );
      return;
    }

    GrihoFeedback.showSuccess(context, 'Unit created successfully.');
    Navigator.of(context).pop(unit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      unitControllerProvider.select((s) => s.isLoading),
    );
    final maxFloors = widget.numberOfFloors < 1 ? 1 : widget.numberOfFloors;
    final floors = [for (var f = 1; f <= maxFloors; f++) f];
    final activeFloor =
        (_selectedFloor != null && floors.contains(_selectedFloor))
        ? _selectedFloor
        : floors.first;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Add Unit')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Iconsax.home_2,
                          size: 24,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configure New Space',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create a residential apartment or commercial unit in this building ($maxFloors ${maxFloors == 1 ? 'floor' : 'floors'} available).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GrihoSectionCard(
                  title: 'Unit Details',
                  subtitle: 'Specify floor location and space identifiers',
                  icon: Iconsax.building,
                  children: [
                    GrihoPickerField<int>(
                      label: 'Floor Level',
                      hint: 'Select floor level',
                      sheetTitle: 'Select Floor Level',
                      searchHint: 'Search floor...',
                      icon: Iconsax.layer,
                      items: floors,
                      value: activeFloor,
                      enabled: !isLoading,
                      itemTitle: formatUnitFloorLabel,
                      onChanged: (val) => setState(() => _selectedFloor = val),
                      validator: (val) =>
                          val == null ? 'Please select a floor level.' : null,
                    ),
                    const SizedBox(height: 16),
                    GrihoTextField(
                      controller: _unitNumberController,
                      label: 'Unit / Flat Number',
                      hint: 'e.g. A-101 or 2B',
                      prefixIcon: Iconsax.tag,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter unit number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    GrihoTextField(
                      controller: _nameController,
                      label: 'Unit Label / Name (Optional)',
                      hint: 'e.g. Family Suite or Studio',
                      prefixIcon: Iconsax.edit_2,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onFieldSubmitted: (_) {
                        if (!isLoading) {
                          _createUnit();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GrihoPrimaryButton(
                  label: isLoading ? 'Creating Unit...' : 'Create Unit',
                  icon: Iconsax.building_4,
                  isLoading: isLoading,
                  onPressed: _createUnit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
