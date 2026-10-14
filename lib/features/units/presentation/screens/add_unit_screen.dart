import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_unit_request.dart';
import '../controllers/unit_controller.dart';

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

  int? _selectedFloor;

  @override
  void initState() {
    super.initState();
    // Default to the first floor if available
    if (widget.numberOfFloors >= 1) {
      _selectedFloor = 1;
    }
  }

  @override
  void dispose() {
    _unitNumberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _floorLabel(int floor) {
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

  Future<void> _createUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFloor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid floor level.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final unitNumber = _unitNumberController.text.trim();
    final name = _nameController.text.trim();

    final request = CreateUnitRequest(
      propertyId: widget.propertyId,
      floorNumber: _selectedFloor!,
      unitNumber: unitNumber,
      name: name.isEmpty ? null : name,
    );

    final unit = await ref.read(unitControllerProvider.notifier).createUnit(
      request: request,
    );

    if (!mounted) {
      return;
    }

    if (unit == null) {
      final state = ref.read(unitControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ?? 'Unable to create unit.',
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
        content: Text('Unit created successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(unit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(unitControllerProvider);
    final maxFloors = widget.numberOfFloors < 1 ? 1 : widget.numberOfFloors;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Add Unit',
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
                // Top Overview Card
                Container(
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
                          Icons.door_front_door_rounded,
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
                              'Configure New Space',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create a residential apartment or commercial unit in this building ($maxFloors ${maxFloors ==
                                  1 ? 'floor' : 'floors'} available).',
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

                // Section: Unit Space Details
                _buildSectionCard(
                  title: 'Unit Details',
                  subtitle: 'Specify floor location and space identifiers',
                  icon: Icons.apartment_rounded,
                  children: [
                    // Floor Dropdown Selector
                    DropdownButtonFormField<int>(
                      initialValue: _selectedFloor,
                      decoration: const InputDecoration(
                        labelText: 'Floor Level',
                        hintText: 'Select floor level',
                        prefixIcon: Icon(Icons.layers_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (int f = 1; f <= maxFloors; f++)
                          DropdownMenuItem<int>(
                            value: f,
                            child: Text(_floorLabel(f)),
                          ),
                      ],
                      onChanged: state.isLoading
                          ? null
                          : (val) {
                        setState(() {
                          _selectedFloor = val;
                        });
                      },
                      validator: (val) {
                        if (val == null) {
                          return 'Please select a floor level.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Unit Number Input
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
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Please enter unit number.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Custom Unit Name Input
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Unit Label / Name (Optional)',
                        hintText: 'e.g. Family Suite or Studio',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                        border: OutlineInputBorder(),
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
                    onPressed: state.isLoading ? null : _createUnit,
                    icon: state.isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add_home_work_rounded),
                    label: Text(
                      state.isLoading ? 'Creating Unit...' : 'Create Unit',
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
}
