import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final numberOfFloors =
        int.tryParse(_numberOfFloorsController.text.trim()) ??
        widget.property.numberOfFloors;

    final updatedProperty = Property(
      id: widget.property.id,
      propertyCode: widget.property.propertyCode,
      ownerId: widget.property.ownerId,
      name: name,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _selectedType,
      status: _selectedStatus,
      numberOfFloors: numberOfFloors,
      createdAt: widget.property.createdAt,
      updatedAt: DateTime.now(),
    );

    final controller = ref.read(propertyControllerProvider.notifier);
    final result = await controller.updateProperty(property: updatedProperty);

    if (!mounted) {
      return;
    }

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(result);
    } else {
      final state = ref.read(propertyControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Unable to update property.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  IconData _propertyTypeIcon(PropertyType type) {
    switch (type) {
      case PropertyType.residential:
        return Icons.home_outlined;
      case PropertyType.commercial:
        return Icons.storefront_outlined;
      case PropertyType.mixedUse:
        return Icons.domain_outlined;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(propertyControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Property',
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
                _buildHeader(theme),

                const SizedBox(height: 24),

                // সেকশন ১: মৌলিক তথ্য ও স্ট্যাটাস
                _buildSectionCard(
                  context,
                  title: '1. Identity & Status',
                  subtitle: 'Update property name, category, and availability',
                  icon: Icons.apartment_rounded,
                  children: [
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Property Code',
                        prefixIcon: const Icon(Icons.qr_code_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Copy Code',
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.property.propertyCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Property code copied to clipboard.',
                                ),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !state.isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Property Name',
                        hintText: 'e.g. Mowlovi Manzil',
                        prefixIcon: Icon(Icons.title_rounded),
                        border: OutlineInputBorder(),
                      ),
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PropertyType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Property Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: PropertyType.values.map((type) {
                        return DropdownMenuItem<PropertyType>(
                          value: type,
                          child: Row(
                            children: [
                              Icon(_propertyTypeIcon(type), size: 18),
                              const SizedBox(width: 8),
                              Text(_propertyTypeLabel(type)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: state.isLoading
                          ? null
                          : (type) {
                              if (type == null) {
                                return;
                              }
                              setState(() {
                                _selectedType = type;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PropertyStatus>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Operational Status',
                        prefixIcon: Icon(Icons.toggle_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: PropertyStatus.values.map((status) {
                        final isActive = status == PropertyStatus.active;
                        return DropdownMenuItem<PropertyStatus>(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.check_circle_outline
                                    : Icons.pause_circle_outline,
                                size: 18,
                                color: isActive ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(_propertyStatusLabel(status)),
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
                  ],
                ),

                const SizedBox(height: 16),

                // সেকশন ২: গঠন ও অবস্থান
                _buildSectionCard(
                  context,
                  title: '2. Structure & Location',
                  subtitle: 'Floors configuration and property address',
                  icon: Icons.layers_outlined,
                  children: [
                    TextFormField(
                      controller: _numberOfFloorsController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !state.isLoading,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Total Number of Floors',
                        hintText: 'e.g. 5',
                        prefixIcon: Icon(Icons.stairs_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final floors = int.tryParse(value?.trim() ?? '');
                        if (floors == null) {
                          return 'Please enter number of floors.';
                        }
                        if (floors < 1) {
                          return 'Floors must be at least 1.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !state.isLoading,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Physical Address',
                        hintText: 'Enter complete property address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // সেকশন ৩: অতিরিক্ত বিবরণ
                _buildSectionCard(
                  context,
                  title: '3. Additional Notes (Optional)',
                  subtitle: 'Landmarks, instructions or property guidelines',
                  icon: Icons.notes_rounded,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !state.isLoading,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Guidelines',
                        hintText:
                            'e.g. Generator available, gates locked after midnight',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // সেভ বাটন
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : _updateProperty,
                    icon: state.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
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

  Widget _buildHeader(ThemeData theme) {
    final isActive = _selectedStatus == PropertyStatus.active;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.edit_location_alt_rounded,
            size: 28,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
    );
  }
}
