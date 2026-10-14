import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';

class EditUnitScreen extends ConsumerStatefulWidget {
  final Unit unit;

  const EditUnitScreen({
    super.key,
    required this.unit,
  });

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

    _unitNumberController = TextEditingController(
      text: widget.unit.unitNumber,
    );

    _nameController = TextEditingController(
      text: widget.unit.name ?? '',
    );

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final floorNumber = int.parse(_floorController.text.trim());
    final unitNumber = _unitNumberController.text.trim();
    final name = _nameController.text.trim();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ?? 'Unable to update unit.',
          ),
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
        content: Text('Unit updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(unitControllerProvider);

    final currentUnitNumber = _unitNumberController.text
        .trim()
        .isNotEmpty
        ? _unitNumberController.text.trim()
        : widget.unit.unitNumber;
    final currentCustomName = _nameController.text
        .trim()
        .isNotEmpty
        ? _nameController.text.trim()
        : widget.unit.name;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Unit',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Unit Summary Card
                _UnitSummaryCard(
                  unitNumber: currentUnitNumber,
                  customName: currentCustomName,
                  floorNumber: int.tryParse(_floorController.text.trim()) ??
                      widget.unit.floorNumber,
                  status: _selectedStatus,
                ),

                const SizedBox(height: 18),

                // Section 1: Space Identifiers & Floor
                _buildSectionCard(
                  title: '1. Location & Identifiers',
                  subtitle: 'Update floor level and unit space naming',
                  icon: Icons.door_front_door_rounded,
                  children: [
                    TextFormField(
                      controller: _floorController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Floor Number',
                        hintText: 'e.g. 1 (use 0 for Ground Floor)',
                        prefixIcon: Icon(Icons.layers_outlined),
                        border: OutlineInputBorder(),
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

                        if (floor < 0) {
                          return 'Floor number cannot be negative.';
                        }

                        return null;
                      },
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _unitNumberController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Unit / Flat Number',
                        hintText: 'e.g. A-101 or 2B',
                        prefixIcon: Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value
                            .trim()
                            .isEmpty) {
                          return 'Please enter unit number.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Custom Label / Name (Optional)',
                        hintText: 'e.g. Corner Family Suite',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Section 2: Occupancy & Status
                _buildSectionCard(
                  title: '2. Tenancy Status',
                  subtitle: 'Current operational state of this unit',
                  icon: Icons.shield_outlined,
                  children: [
                    DropdownButtonFormField<UnitStatus>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Unit Status',
                        prefixIcon: Icon(Icons.tune_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: UnitStatus.values.map((status) {
                        return DropdownMenuItem<UnitStatus>(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                _statusIcon(status),
                                size: 18,
                                color: _statusColor(status),
                              ),
                              const SizedBox(width: 8),
                              Text(_statusLabel(status)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: state.isLoading
                          ? null
                          : (status) {
                        if (status == null) {
                          return;
                        }
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusDescription(_selectedStatus),
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

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : _updateUnit,
                    icon: state.isLoading
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
                      state.isLoading ? 'Saving Changes...' : 'Save Changes',
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

  String _statusLabel(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return 'Available / Vacant';
      case UnitStatus.occupied:
        return 'Occupied';
      case UnitStatus.reserved:
        return 'Reserved';
      case UnitStatus.inactive:
        return 'Inactive / Maintenance';
    }
  }

  IconData _statusIcon(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return Icons.check_circle_outline_rounded;
      case UnitStatus.occupied:
        return Icons.person_rounded;
      case UnitStatus.reserved:
        return Icons.bookmark_outline_rounded;
      case UnitStatus.inactive:
        return Icons.block_rounded;
    }
  }

  Color _statusColor(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return Colors.blue.shade700;
      case UnitStatus.occupied:
        return Colors.green.shade700;
      case UnitStatus.reserved:
        return Colors.amber.shade900;
      case UnitStatus.inactive:
        return Colors.grey.shade700;
    }
  }

  String _statusDescription(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return 'This unit is marked as vacant and can be assigned to new residents in tenancy workflows.';
      case UnitStatus.occupied:
        return 'This unit currently has an active tenancy associated with it.';
      case UnitStatus.reserved:
        return 'This unit is on temporary hold and will be hidden from instant availability.';
      case UnitStatus.inactive:
        return 'This unit is under maintenance or out of service and cannot be allocated.';
    }
  }
}

// ============================================================================
// UNIT SUMMARY CARD
// ============================================================================

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

  String _floorLabel(int floor) {
    if (floor == 0) {
      return 'Ground Floor';
    }
    if (floor == 1) {
      return '1st Floor';
    }
    if (floor == 2) {
      return '2nd Floor';
    }
    if (floor == 3) {
      return '3rd Floor';
    }
    return '$floor-th Floor';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, color) = switch (status) {
      UnitStatus.available => ('Available', Colors.blue.shade800),
      UnitStatus.occupied => ('Occupied', Colors.green.shade800),
      UnitStatus.reserved => ('Reserved', Colors.amber.shade900),
      UnitStatus.inactive => ('Inactive', Colors.grey.shade800),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
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
              Icons.apartment_rounded,
              size: 26,
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
                  _floorLabel(floorNumber),
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
