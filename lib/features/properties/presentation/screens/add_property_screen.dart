import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_property_request.dart';
import '../../domain/entities/property.dart';
import '../controllers/property_controller.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({
    super.key,
  });

  @override
  ConsumerState<AddPropertyScreen> createState() =>
      _AddPropertyScreenState();
}

class _AddPropertyScreenState
    extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _numberOfFloorsController =
  TextEditingController(text: '1');

  PropertyType _selectedType =
      PropertyType.residential;

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

    final numberOfFloors = int.parse(
      _numberOfFloorsController.text.trim(),
    );

    final request = CreatePropertyRequest(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      description:
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _selectedType,
      numberOfFloors: numberOfFloors,
    );

    final property = await ref
        .read(propertyControllerProvider.notifier)
        .createProperty(
      request: request,
    );

    if (!mounted) {
      return;
    }

    if (property == null) {
      final state = ref.read(
        propertyControllerProvider,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ??
                'Unable to create property.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(property);
  }

  String _propertyTypeLabel(
      PropertyType type,
      ) {
    switch (type) {
      case PropertyType.residential:
        return 'Residential';

      case PropertyType.commercial:
        return 'Commercial';

      case PropertyType.mixedUse:
        return 'Mixed Use';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      propertyControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Property'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Property Information',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),

                const SizedBox(height: 8),

                Text(
                  'Add the basic information about your property.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textCapitalization:
                  TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Property Name',
                    hintText: 'e.g. Green View',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final name =
                        value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Please enter a property name.';
                    }

                    if (name.length < 2) {
                      return 'Property name must be at least 2 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<PropertyType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Property Type',
                    border: OutlineInputBorder(),
                  ),
                  items: PropertyType.values.map(
                        (type) {
                      return DropdownMenuItem<
                          PropertyType>(
                        value: type,
                        child: Text(
                          _propertyTypeLabel(type),
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller:
                  _numberOfFloorsController,
                  keyboardType:
                  TextInputType.number,
                  textInputAction:
                  TextInputAction.next,
                  decoration:
                  const InputDecoration(
                    labelText: 'Number of Floors',
                    hintText: 'e.g. 5',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final floors = int.tryParse(
                      value?.trim() ?? '',
                    );

                    if (floors == null) {
                      return 'Please enter the number of floors.';
                    }

                    if (floors < 1) {
                      return 'Number of floors must be at least 1.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller:
                  _addressController,
                  textCapitalization:
                  TextCapitalization.sentences,
                  maxLines: 2,
                  decoration:
                  const InputDecoration(
                    labelText: 'Address',
                    hintText:
                    'Enter property address',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller:
                  _descriptionController,
                  textCapitalization:
                  TextCapitalization.sentences,
                  maxLines: 4,
                  decoration:
                  const InputDecoration(
                    labelText: 'Description',
                    hintText:
                    'Optional description',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.isLoading
                        ? null
                        : _createProperty,
                    child: state.isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Create Property',
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
}