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
  ConsumerState<EditUnitScreen> createState() =>
      _EditUnitScreenState();
}

class _EditUnitScreenState
    extends ConsumerState<EditUnitScreen> {
  final _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _floorController;

  late final TextEditingController
  _unitNumberController;

  late final TextEditingController
  _nameController;

  late UnitStatus _selectedStatus;

  @override
  void initState() {
    super.initState();

    _floorController =
        TextEditingController(
          text: widget.unit.floorNumber
              .toString(),
        );

    _unitNumberController =
        TextEditingController(
          text: widget.unit.unitNumber,
        );

    _nameController =
        TextEditingController(
          text: widget.unit.name ?? '',
        );

    _selectedStatus =
        widget.unit.status;
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

    final floorNumber = int.parse(
      _floorController.text.trim(),
    );

    final unitNumber =
    _unitNumberController.text.trim();

    final name =
    _nameController.text.trim();

    final updatedUnit =
    widget.unit.copyWith(
      floorNumber: floorNumber,
      unitNumber: unitNumber,
      name: name.isEmpty
          ? null
          : name,
      status: _selectedStatus,
      updatedAt: DateTime.now(),
    );

    final result = await ref
        .read(
      unitControllerProvider.notifier,
    )
        .updateUnit(
      unit: updatedUnit,
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      final state = ref.read(
        unitControllerProvider,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ??
                'Unable to update unit.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      unitControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Edit Unit'),
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

                const SizedBox(height: 32),

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
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text =
                        value?.trim() ??
                            '';

                    final floor =
                    int.tryParse(text);

                    if (text.isEmpty) {
                      return 'Please enter floor number.';
                    }

                    if (floor == null) {
                      return 'Floor number must be a number.';
                    }

                    if (floor < 0) {
                      return 'Floor number cannot be negative.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

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
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.trim()
                        .isEmpty ??
                        true) {
                      return 'Please enter unit number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

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

                DropdownButtonFormField<
                    UnitStatus>(
                  initialValue:
                  _selectedStatus,
                  decoration:
                  const InputDecoration(
                    labelText: 'Status',
                    border:
                    OutlineInputBorder(),
                  ),
                  items: UnitStatus.values
                      .map(
                        (status) {
                      return DropdownMenuItem<
                          UnitStatus>(
                        value: status,
                        child: Text(
                          _statusLabel(
                            status,
                          ),
                        ),
                      );
                    },
                  )
                      .toList(),
                  onChanged: (status) {
                    if (status == null) {
                      return;
                    }

                    setState(() {
                      _selectedStatus =
                          status;
                    });
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width:
                  double.infinity,
                  child: FilledButton(
                    onPressed:
                    state.isLoading
                        ? null
                        : _updateUnit,
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
                      'Save Changes',
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

  String _statusLabel(
      UnitStatus status,
      ) {
    switch (status) {
      case UnitStatus.available:
        return 'Available';

      case UnitStatus.occupied:
        return 'Occupied';

      case UnitStatus.reserved:
        return 'Reserved';

      case UnitStatus.inactive:
        return 'Inactive';
    }
  }
}