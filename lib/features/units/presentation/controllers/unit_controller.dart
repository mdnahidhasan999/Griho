import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_unit_request.dart';
import '../../domain/entities/unit.dart';
import '../../domain/usecases/create_unit.dart';
import '../../domain/usecases/delete_unit.dart';
import '../../domain/usecases/get_unit.dart';
import '../../domain/usecases/get_units_by_property_id.dart';
import '../../domain/usecases/update_unit.dart';
import '../providers/unit_usecase_provider.dart';

final unitControllerProvider =
NotifierProvider<UnitController, UnitControllerState>(
  UnitController.new,
);

class UnitControllerState {
  final bool isLoading;
  final List<Unit> units;
  final Unit? selectedUnit;
  final String? errorMessage;

  const UnitControllerState({
    this.isLoading = false,
    this.units = const [],
    this.selectedUnit,
    this.errorMessage,
  });

  UnitControllerState copyWith({
    bool? isLoading,
    List<Unit>? units,
    Unit? selectedUnit,
    String? errorMessage,
    bool clearSelectedUnit = false,
    bool clearError = false,
  }) {
    return UnitControllerState(
      isLoading: isLoading ?? this.isLoading,
      units: units ?? this.units,
      selectedUnit: clearSelectedUnit
          ? null
          : selectedUnit ?? this.selectedUnit,
      errorMessage: clearError
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class UnitController extends Notifier<UnitControllerState> {
  late final CreateUnit _createUnit;
  late final GetUnit _getUnit;
  late final GetUnitsByPropertyId _getUnitsByPropertyId;
  late final UpdateUnit _updateUnit;
  late final DeleteUnit _deleteUnit;

  @override
  UnitControllerState build() {
    _createUnit = ref.read(createUnitProvider);
    _getUnit = ref.read(getUnitProvider);
    _getUnitsByPropertyId =
        ref.read(getUnitsByPropertyIdProvider);
    _updateUnit = ref.read(updateUnitProvider);
    _deleteUnit = ref.read(deleteUnitProvider);

    return const UnitControllerState();
  }

  Future<void> loadUnits({
    required String propertyId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final units = await _getUnitsByPropertyId(
        propertyId,
      );

      state = state.copyWith(
        isLoading: false,
        units: units,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadUnit({
    required String unitId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final unit = await _getUnit(unitId);

      if (unit == null) {
        state = state.copyWith(
          isLoading: false,
          clearSelectedUnit: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        selectedUnit: unit,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<Unit?> createUnit({
    required CreateUnitRequest request,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final createdUnit = await _createUnit(request);

      state = state.copyWith(
        isLoading: false,
        units: [
          createdUnit,
          ...state.units,
        ],
        selectedUnit: createdUnit,
      );

      return createdUnit;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<Unit?> updateUnit({
    required Unit unit,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final updatedUnit = await _updateUnit(unit);

      final updatedUnits = state.units.map((item) {
        if (item.id == updatedUnit.id) {
          return updatedUnit;
        }

        return item;
      }).toList();

      state = state.copyWith(
        isLoading: false,
        units: updatedUnits,
        selectedUnit: updatedUnit,
      );

      return updatedUnit;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<bool> deleteUnit({
    required String unitId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await _deleteUnit(unitId);

      final remainingUnits = state.units
          .where(
            (unit) => unit.id != unitId,
      )
          .toList();

      final selectedUnit = state.selectedUnit;

      state = state.copyWith(
        isLoading: false,
        units: remainingUnits,
        clearSelectedUnit:
        selectedUnit?.id == unitId,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return false;
    }
  }

  void clearError() {
    state = state.copyWith(
      clearError: true,
    );
  }

  void clearSelectedUnit() {
    state = state.copyWith(
      clearSelectedUnit: true,
    );
  }
}