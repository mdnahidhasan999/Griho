// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/property.dart';
import '../controllers/property_controller.dart';

class EditPropertyScreen extends ConsumerStatefulWidget {
  final Property property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  ConsumerState<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends ConsumerState<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _numberOfFloorsController;

  late PropertyType _selectedType;
  late PropertyStatus _selectedStatus;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.property.name);
    _addressController = TextEditingController(
      text: widget.property.address ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.property.description ?? '',
    );
    _numberOfFloorsController = TextEditingController(
      text: widget.property.numberOfFloors.toString(),
    );

    _selectedType = widget.property.type;
    _selectedStatus = widget.property.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _numberOfFloorsController.dispose();
    super.dispose();
  }

  Future<void> _updateProperty() async {
    FocusScope.of(context).unfocus();
    if (ref.read(propertyControllerProvider).isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final description = _descriptionController.text.trim();
    final numberOfFloors =
        int.tryParse(_numberOfFloorsController.text.trim()) ??
        widget.property.numberOfFloors;

    // Skip Firestore write if nothing changed.
    final unchanged =
        name == widget.property.name.trim() &&
        address == (widget.property.address?.trim() ?? '') &&
        description == (widget.property.description?.trim() ?? '') &&
        numberOfFloors == widget.property.numberOfFloors &&
        _selectedType == widget.property.type &&
        _selectedStatus == widget.property.status;

    if (unchanged) {
      GrihoFeedback.showInfo(context, 'No changes to save.');
      Navigator.of(context).pop();
      return;
    }

    // Use copyWith so tenantUserIds and other internal fields are preserved.
    final updatedProperty = widget.property.copyWith(
      name: name,
      address: address.isEmpty ? null : address,
      description: description.isEmpty ? null : description,
      type: _selectedType,
      status: _selectedStatus,
      numberOfFloors: numberOfFloors,
      updatedAt: DateTime.now(),
    );

    final controller = ref.read(propertyControllerProvider.notifier);
    final result = await controller.updateProperty(property: updatedProperty);

    if (!mounted) {
      return;
    }

    if (result != null) {
      GrihoFeedback.showSuccess(context, 'Property updated successfully.');
      Navigator.of(context).pop(result);
    } else {
      final state = ref.read(propertyControllerProvider);
      GrihoFeedback.showError(
        context,
        state.errorMessage ?? 'Unable to update property.',
      );
    }
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

  String _propertyStatusLabel(PropertyStatus status) => switch (status) {
    PropertyStatus.active => 'Active',
    PropertyStatus.inactive => 'Inactive',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      propertyControllerProvider.select((s) => s.isLoading),
    );
    final isActive = _selectedStatus == PropertyStatus.active;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Edit Property')),
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
                          Iconsax.edit_2,
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
                              widget.property.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${widget.property.propertyCode}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isActive
                                      ? GrihoColors.emerald
                                      : GrihoColors.warning)
                                  .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? GrihoColors.emerald
                                : GrihoColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GrihoSectionCard(
                  title: '1. Identity & Status',
                  subtitle: 'Update property name, category, and availability',
                  icon: Iconsax.buildings_2,
                  children: [
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Property Code',
                        prefixIcon: const Icon(
                          Iconsax.code,
                          color: GrihoColors.emerald,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Copy Code',
                          icon: const Icon(Iconsax.copy, size: 19),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.property.propertyCode),
                            );
                            GrihoFeedback.showSuccess(
                              context,
                              'Property code copied to clipboard.',
                            );
                          },
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                      ),
                      child: Text(
                        widget.property.propertyCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GrihoTextField(
                      controller: _nameController,
                      label: 'Property Name',
                      hint: 'e.g. Mowlovi Manzil',
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
                            child: _OptionTile(
                              label: _propertyTypeLabel(PropertyType.values[i]),
                              icon: _propertyTypeIcon(PropertyType.values[i]),
                              accentColor: GrihoColors.emerald,
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
                    const SizedBox(height: 18),
                    Text(
                      'Operational Status',
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
                          i < PropertyStatus.values.length;
                          i++
                        ) ...[
                          Expanded(
                            child: _OptionTile(
                              label: _propertyStatusLabel(
                                PropertyStatus.values[i],
                              ),
                              icon:
                                  PropertyStatus.values[i] ==
                                      PropertyStatus.active
                                  ? Iconsax.tick_circle
                                  : Iconsax.pause_circle,
                              accentColor:
                                  PropertyStatus.values[i] ==
                                      PropertyStatus.active
                                  ? GrihoColors.emerald
                                  : GrihoColors.warning,
                              selected:
                                  _selectedStatus == PropertyStatus.values[i],
                              enabled: !isLoading,
                              horizontal: true,
                              onTap: () => setState(
                                () =>
                                    _selectedStatus = PropertyStatus.values[i],
                              ),
                            ),
                          ),
                          if (i != PropertyStatus.values.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GrihoSectionCard(
                  title: '2. Structure & Location',
                  subtitle: 'Floors configuration and property address',
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
                      hint: 'Enter complete property address',
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
                  subtitle: 'Landmarks, instructions or property guidelines',
                  icon: Iconsax.document_text,
                  children: [
                    GrihoTextField(
                      controller: _descriptionController,
                      label: 'Description / Guidelines',
                      hint:
                          'e.g. Generator available, gates locked after midnight',
                      prefixIcon: Iconsax.note_2,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !isLoading,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GrihoPrimaryButton(
                  label: isLoading ? 'Saving Changes...' : 'Save Changes',
                  icon: Iconsax.tick_circle,
                  isLoading: isLoading,
                  onPressed: _updateProperty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.horizontal = false,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = selected ? accentColor : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          vertical: 12,
          horizontal: horizontal ? 12 : 8,
        ),
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
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: fgColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: fgColor,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 21, color: fgColor),
                  const SizedBox(height: 6),
                  Text(
                    label,
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
