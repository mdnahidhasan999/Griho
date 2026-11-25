// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/create_property_request.dart';
import '../../domain/entities/property.dart';
import '../controllers/property_controller.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _numberOfFloorsController = TextEditingController(text: '1');

  PropertyType _selectedType = PropertyType.residential;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _numberOfFloorsController.dispose();
    super.dispose();
  }

  Future<void> _createProperty() async {
    FocusScope.of(context).unfocus();
    if (ref.read(propertyControllerProvider).isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final numberOfFloors =
        int.tryParse(_numberOfFloorsController.text.trim()) ?? 1;

    final request = CreatePropertyRequest(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _selectedType,
      numberOfFloors: numberOfFloors,
    );

    final property = await ref
        .read(propertyControllerProvider.notifier)
        .createProperty(request: request);

    if (!mounted) {
      return;
    }

    if (property == null) {
      final state = ref.read(propertyControllerProvider);
      GrihoFeedback.showError(
        context,
        state.errorMessage ?? 'Unable to create property.',
      );
      return;
    }

    GrihoFeedback.showSuccess(context, 'Property added successfully!');
    Navigator.of(context).pop(property);
  }

  String _propertyTypeLabel(PropertyType type) => switch (type) {
    PropertyType.residential => 'Residential',
    PropertyType.commercial => 'Commercial',
    PropertyType.mixedUse => 'Mixed Use',
  };

  IconData _propertyTypeIcon(PropertyType type) => switch (type) {
    PropertyType.residential => Iconsax.home_2,
    PropertyType.commercial => Iconsax.shop,
    PropertyType.mixedUse => Iconsax.buildings_2,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      propertyControllerProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Add Property')),
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
                          Iconsax.building_4,
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
                              'New Building or House',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enter property specifications to set up units and tenants.',
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
                  title: '1. Identity & Classification',
                  subtitle: 'Name and usage type of your building',
                  icon: Iconsax.buildings_2,
                  children: [
                    GrihoTextField(
                      controller: _nameController,
                      label: 'Property Name',
                      hint: 'e.g. Mowlovi Manzil or Green View',
                      prefixIcon: Iconsax.building,
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) {
                          return 'Please enter a property name.';
                        }
                        if (name.length < 2) {
                          return 'Property name must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Property Category',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (
                          var i = 0;
                          i < PropertyType.values.length;
                          i++
                        ) ...[
                          Expanded(
                            child: _PropertyCategoryTile(
                              label: _propertyTypeLabel(PropertyType.values[i]),
                              icon: _propertyTypeIcon(PropertyType.values[i]),
                              selected: _selectedType == PropertyType.values[i],
                              enabled: !isLoading,
                              onTap: () => setState(
                                () => _selectedType = PropertyType.values[i],
                              ),
                            ),
                          ),
                          if (i != PropertyType.values.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GrihoSectionCard(
                  title: '2. Structure & Location',
                  subtitle: 'Floor details and physical address',
                  icon: Iconsax.layer,
                  children: [
                    TextFormField(
                      controller: _numberOfFloorsController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Total Number of Floors',
                        hintText: 'e.g. 5',
                        prefixIcon: Icon(
                          Iconsax.layer,
                          color: GrihoColors.emerald,
                          size: 20,
                        ),
                        helperText: 'You can add units under each floor later.',
                      ),
                      validator: (value) {
                        final floors = int.tryParse(value?.trim() ?? '');
                        if (floors == null) {
                          return 'Please enter number of floors.';
                        }
                        if (floors < 1) {
                          return 'Floors must be at least 1.';
                        }
                        if (floors > 200) {
                          return 'Floors cannot exceed 200.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    GrihoTextField(
                      controller: _addressController,
                      label: 'Physical Address',
                      hint: 'e.g. House 12, Road 4, Sector 7, Uttara',
                      prefixIcon: Iconsax.location,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !isLoading,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GrihoSectionCard(
                  title: '3. Additional Notes (Optional)',
                  subtitle: 'Landmarks, amenities or specific instructions',
                  icon: Iconsax.document_text,
                  children: [
                    GrihoTextField(
                      controller: _descriptionController,
                      label: 'Description / Rules',
                      hint:
                          'e.g. Generator available, main gate closes at 11 PM',
                      prefixIcon: Iconsax.note_2,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !isLoading,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GrihoPrimaryButton(
                  label: isLoading
                      ? 'Creating Property...'
                      : 'Save & Create Property',
                  icon: Iconsax.tick_circle,
                  isLoading: isLoading,
                  onPressed: _createProperty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCategoryTile extends StatelessWidget {
  const _PropertyCategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? GrihoColors.emerald.withValues(alpha: 0.14)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? GrihoColors.emerald
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? GrihoColors.emerald
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? GrihoColors.emerald
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
