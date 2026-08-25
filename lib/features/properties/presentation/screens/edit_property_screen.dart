import 'package:flutter/material.dart';
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
    final name = _nameController.text.trim();

    final numberOfFloors = int.tryParse(_numberOfFloorsController.text.trim());

    if (name.isEmpty) {
      return;
    }

    if (numberOfFloors == null || numberOfFloors < 1) {
      return;
    }

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
      Navigator.of(context).pop(result);
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
    final state = ref.watch(propertyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Property')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Property Name',
                hintText: 'Enter property name',
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<PropertyType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Property Type'),
              items: PropertyType.values.map((type) {
                return DropdownMenuItem<PropertyType>(
                  value: type,
                  child: Text(_propertyTypeLabel(type)),
                );
              }).toList(),
              onChanged: (type) {
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
              decoration: const InputDecoration(labelText: 'Status'),
              items: PropertyStatus.values.map((status) {
                return DropdownMenuItem<PropertyStatus>(
                  value: status,
                  child: Text(_propertyStatusLabel(status)),
                );
              }).toList(),
              onChanged: (status) {
                if (status == null) {
                  return;
                }

                setState(() {
                  _selectedStatus = status;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _numberOfFloorsController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Number of Floors',
                hintText: 'e.g. 5',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter property address',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter property description',
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: state.isLoading ? null : _updateProperty,
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
