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
  ConsumerState<AddUnitScreen> createState() =>
      _AddUnitScreenState();
}

class _AddUnitScreenState
    extends ConsumerState<AddUnitScreen> {
  final _formKey =
  GlobalKey<FormState>();

  final _floorController =
  TextEditingController();

  final _unitNumberController =
  TextEditingController();

  final _nameController =
  TextEditingController();

  final _rentController =
  TextEditingController();

  @override
  void dispose() {
    _floorController.dispose();
    _unitNumberController.dispose();
    _nameController.dispose();
    _rentController.dispose();

    super.dispose();
  }

  Future<void> _createUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final floorNumber = int.parse(
      _floorController.text.trim(),
    );

    final unitNumber =
    _unitNumberController.text.trim();

    final name =
    _nameController.text.trim();

    final rentText =
    _rentController.text.trim();

    final monthlyRent =
    rentText.isEmpty
        ? null
        : double.parse(rentText);

    final request = CreateUnitRequest(
      propertyId: widget.propertyId,
      floorNumber: floorNumber,
      unitNumber: unitNumber,
      name: name.isEmpty
          ? null
          : name,
      monthlyRent: monthlyRent,
    );

    final unit = await ref
        .read(
      unitControllerProvider.notifier,
    )
        .createUnit(
      request: request,
    );

    if (!mounted) {
      return;
    }

    if (unit == null) {
      final state = ref.read(
        unitControllerProvider,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ??
                'Unable to create unit.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(unit);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      unitControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Unit',
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Unit Information',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),

                const SizedBox(height: 8),

                Text(
                  'Add a unit to this property.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(height: 12),

                Text(
                  'This property has '
                      '${widget.numberOfFloors} '
                      '${widget.numberOfFloors == 1 ? 'floor' : 'floors'}.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),

                const SizedBox(height: 32),

                // ==================================================
                // FLOOR
                // ==================================================

                TextFormField(
                  controller:
                  _floorController,

                  keyboardType:
                  TextInputType.number,

                  textInputAction:
                  TextInputAction.next,

                  decoration:
                  const InputDecoration(
                    labelText:
                    'Floor Number',
                    hintText:
                    'e.g. 1',
                    border:
                    OutlineInputBorder(),
                  ),

                  validator: (value) {
                    final text =
                        value?.trim() ??
                            '';

                    if (text.isEmpty) {
                      return 'Please enter floor number.';
                    }

                    final floor =
                    int.tryParse(text);

                    if (floor == null) {
                      return 'Floor number must be a number.';
                    }

                    if (floor < 1) {
                      return 'Floor number must be at least 1.';
                    }

                    if (floor >
                        widget.numberOfFloors) {
                      return 'This property has only '
                          '${widget.numberOfFloors} '
                          '${widget.numberOfFloors == 1 ? 'floor' : 'floors'}.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ==================================================
                // UNIT NUMBER
                // ==================================================

                TextFormField(
                  controller:
                  _unitNumberController,

                  textCapitalization:
                  TextCapitalization
                      .characters,

                  textInputAction:
                  TextInputAction.next,

                  decoration:
                  const InputDecoration(
                    labelText:
                    'Unit Number',
                    hintText:
                    'e.g. A-101',
                    border:
                    OutlineInputBorder(),
                  ),

                  validator: (value) {
                    final unitNumber =
                        value?.trim() ??
                            '';

                    if (unitNumber
                        .isEmpty) {
                      return 'Please enter unit number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ==================================================
                // UNIT NAME
                // ==================================================

                TextFormField(
                  controller:
                  _nameController,

                  textCapitalization:
                  TextCapitalization
                      .words,

                  textInputAction:
                  TextInputAction.next,

                  decoration:
                  const InputDecoration(
                    labelText:
                    'Unit Name',
                    hintText:
                    'Optional, e.g. Family Apartment',
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // MONTHLY RENT
                // ==================================================

                TextFormField(
                  controller:
                  _rentController,

                  keyboardType:
                  const TextInputType
                      .numberWithOptions(
                    decimal: true,
                  ),

                  textInputAction:
                  TextInputAction.done,

                  decoration:
                  const InputDecoration(
                    labelText:
                    'Monthly Rent',
                    hintText:
                    'Optional, e.g. 15000',
                    prefixText: '৳ ',
                    border:
                    OutlineInputBorder(),
                  ),

                  validator: (value) {
                    final text =
                        value?.trim() ??
                            '';

                    if (text.isEmpty) {
                      return null;
                    }

                    final rent =
                    double.tryParse(
                      text,
                    );

                    if (rent == null) {
                      return 'Please enter a valid rent.';
                    }

                    if (rent < 0) {
                      return 'Rent cannot be negative.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // ==================================================
                // CREATE
                // ==================================================

                SizedBox(
                  width:
                  double.infinity,

                  child: FilledButton(
                    onPressed:
                    state.isLoading
                        ? null
                        : _createUnit,

                    child:
                    state.isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Create Unit',
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