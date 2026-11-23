// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';
import '../widgets/unit_ui_helpers.dart';

class EditUnitScreen extends ConsumerStatefulWidget {
  final Unit unit;

  const EditUnitScreen({super.key, required this.unit});

  @override
  ConsumerState<EditUnitScreen> createState() => _EditUnitScreenState();
}

class _EditUnitScreenState extends ConsumerState<EditUnitScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _floorController;
  late final TextEditingController _unitNumberController;
  late final TextEditingController _nameController;

  late UnitStatus _selectedStatus;

  @override
  void initState() {
    super.initState();

    _floorController = TextEditingController(
      text: widget.unit.floorNumber.toString(),
    );
    _unitNumberController = TextEditingController(text: widget.unit.unitNumber);
    _nameController = TextEditingController(text: widget.unit.name ?? '');
    _selectedStatus = widget.unit.status;
  }

  @override
  void dispose() {
    _floorController.dispose();
    _unitNumberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateUnit() async {
    FocusScope.of(context).unfocus();
    if (ref.read(unitControllerProvider).isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final floorNumber = int.tryParse(_floorController.text.trim());
    if (floorNumber == null || floorNumber < 1) {
      GrihoFeedback.showError(context, 'Please enter a valid floor number.');
      return;
    }

    final unitNumber = _unitNumberController.text.trim();
    final name = _nameController.text.trim();

    // Skip Firestore write if nothing changed.
    final unchanged =
        floorNumber == widget.unit.floorNumber &&
            unitNumber == widget.unit.unitNumber.trim() &&
            name == (widget.unit.name?.trim() ?? '') &&
            _selectedStatus == widget.unit.status;

    if (unchanged) {
      GrihoFeedback.showInfo(context, 'No changes to save.');
      Navigator.of(context).pop();
      return;
    }

    final updatedUnit = widget.unit.copyWith(
      floorNumber: floorNumber,
      unitNumber: unitNumber,
      name: name.isEmpty ? null : name,
      status: _selectedStatus,
      updatedAt: DateTime.now(),
    );

    final result = await ref
        .read(unitControllerProvider.notifier)
        .updateUnit(unit: updatedUnit);

    if (!mounted) {
      return;
    }

    if (result == null) {
      final state = ref.read(unitControllerProvider);
      GrihoFeedback.showError(
        context,
        state.errorMessage ?? 'Unable to update unit.',
      );
      return;
    }

    GrihoFeedback.showSuccess(context, 'Unit updated successfully.');
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      unitControllerProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Edit Unit')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only this card listens to text edits so the form does not rebuild per keystroke.
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _floorController,
                    _unitNumberController,
                    _nameController,
                  ]),
                  builder: (context, _) {
                    final unitText = _unitNumberController.text.trim();
                    final nameText = _nameController.text.trim();
                    return _UnitSummaryCard(
                      unitNumber: unitText.isNotEmpty
                          ? unitText
                          : widget.unit.unitNumber,
                      customName: nameText.isNotEmpty
                          ? nameText
                          : widget.unit.name,
                      floorNumber:
                      int.tryParse(_floorController.text.trim()) ??
                          widget.unit.floorNumber,
                      status: _selectedStatus,
                    );
                  },
                ),
                const SizedBox(height: 18),
                GrihoSectionCard(
                  title: '1. Location & Identifiers',
                  subtitle: 'Update floor level and unit space naming',
                  icon: Iconsax.home_2,
                  children: [
                    TextFormField(
                      controller: _floorController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Floor Number',
                        hintText: 'e.g. 1',
                        prefixIcon: Icon(
                          Iconsax.layer,
                          color: GrihoColors.emerald,
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Please enter floor number.';
                        }
                        final floor = int.tryParse(text);
                        if (floor == null) {
                          return 'Floor number must be a valid number.';
                        }
                        if (floor < 1) {
                          return 'Floor number must be at least 1.';
                        }
                        if (floor > 200) {
                          return 'Floor number cannot exceed 200.';
                        }
                        return null;
                      },
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
                      label: 'Custom Label / Name (Optional)',
                      hint: 'e.g. Corner Family Suite',
                      prefixIcon: Iconsax.edit_2,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GrihoSectionCard(
                  title: '2. Tenancy Status',
                  subtitle: 'Current operational state of this unit',
                  icon: Iconsax.shield_tick,
                  children: [
                    Text(
                      'Unit Status',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < UnitStatus.values.length; i++) ...[
                          Expanded(
                            child: _UnitStatusTile(
                              status: UnitStatus.values[i],
                              selected: _selectedStatus == UnitStatus.values[i],
                              enabled: !isLoading,
                              onTap: () => setState(
                                    () => _selectedStatus = UnitStatus.values[i],
                              ),
                            ),
                          ),
                          if (i != UnitStatus.values.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
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
                            color: unitStatusColor(_selectedStatus),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              unitStatusDescription(_selectedStatus),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GrihoPrimaryButton(
                  label: isLoading ? 'Saving Changes...' : 'Save Changes',
                  icon: Iconsax.tick_circle,
                  isLoading: isLoading,
                  onPressed: _updateUnit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitStatusTile extends StatelessWidget {
  const _UnitStatusTile({
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UnitStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = unitStatusColor(status);
    final fgColor = selected ? accentColor : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.14)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(unitStatusIcon(status), size: 21, color: fgColor),
            const SizedBox(height: 6),
            Text(
              unitStatusLabel(status, detailed: false),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitSummaryCard extends StatelessWidget {
  final String unitNumber;
  final String? customName;
  final int floorNumber;
  final UnitStatus status;

  const _UnitSummaryCard({
    required this.unitNumber,
    required this.customName,
    required this.floorNumber,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              Iconsax.building,
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
                  customName?.isNotEmpty == true
                      ? '$customName (Unit $unitNumber)'
                      : 'Unit $unitNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatUnitFloorLabel(floorNumber),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          UnitStatusChip(status: status),
        ],
      ),
    );
  }
}
