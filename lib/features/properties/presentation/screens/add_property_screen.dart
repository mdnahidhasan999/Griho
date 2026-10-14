import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (!_formKey.currentState!.validate()) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Unable to create property.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Property added successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(property);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(propertyControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Add Property',
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
                // ============================================================
                // হেডার
                // ============================================================
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add_home_work_rounded,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ============================================================
                // সেকশন ১: প্রোপার্টি আইডেন্টিটি
                // ============================================================
                _buildSectionCard(
                  context,
                  title: '1. Identity & Classification',
                  subtitle: 'Name and usage type of your building',
                  icon: Icons.apartment_rounded,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !state.isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Property Name',
                        hintText: 'e.g. Mowlovi Manzil or Green View',
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
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedType = value;
                              });
                            },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ============================================================
                // সেকশন ২: গঠন ও ঠিকানা
                // ============================================================
                _buildSectionCard(
                  context,
                  title: '2. Structure & Location',
                  subtitle: 'Floor details and physical address',
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
                        hintText: 'e.g. House 12, Road 4, Sector 7, Uttara',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ============================================================
                // সেকশন ৩: অতিরিক্ত তথ্য (ঐচ্ছিক)
                // ============================================================
                _buildSectionCard(
                  context,
                  title: '3. Additional Notes (Optional)',
                  subtitle: 'Landmarks, amenities or specific instructions',
                  icon: Icons.notes_rounded,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !state.isLoading,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Rules',
                        hintText:
                            'e.g. Generator available, main gate closes at 11 PM',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ============================================================
                // ক্রিয়েট বাটন
                // ============================================================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : _createProperty,
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
                      state.isLoading
                          ? 'Creating Property...'
                          : 'Save & Create Property',
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
