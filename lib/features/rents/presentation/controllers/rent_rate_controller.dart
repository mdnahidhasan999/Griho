import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/create_rent_rate_request.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/usecases/change_floor_rent.dart';
import '../../domain/usecases/change_property_rent.dart';
import '../../domain/usecases/change_unit_rent.dart';
import '../../domain/usecases/create_initial_rent_rate.dart';

class RentRateController extends StateNotifier<AsyncValue<void>> {
  final CreateInitialRentRate _createInitialRentRate;

  final ChangeUnitRent _changeUnitRent;

  final ChangeFloorRent _changeFloorRent;

  final ChangePropertyRent _changePropertyRent;

  RentRateController({
    required this._createInitialRentRate,
    required this._changeUnitRent,
    required this._changeFloorRent,
    required this._changePropertyRent,
  }) : super(const AsyncData(null));

  // ============================================================
  // CREATE INITIAL RENT RATE
  // ============================================================

  Future<RentRate?> createInitialRentRate({
    required CreateRentRateRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final rentRate = await _createInitialRentRate(
        request,
      );

      state = const AsyncData(null);

      return rentRate;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================

  Future<RentRate?> changeUnitRent({
    required String unitId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    state = const AsyncLoading();

    try {
      final rentRate = await _changeUnitRent(
        unitId: unitId,
        ownerId: ownerId,
        amount: amount,
        effectiveFrom: effectiveFrom,
      );

      state = const AsyncData(null);

      return rentRate;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // CHANGE FLOOR RENT
  // ============================================================
  //
  // amount = adjustment amount
  //
  // increase:
  // current rent + amount
  //
  // decrease:
  // current rent - amount
  //
  // ============================================================

  Future<List<RentRate>?> changeFloorRent({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    state = const AsyncLoading();

    try {
      final rentRates = await _changeFloorRent(
        propertyId: propertyId,
        floorNumber: floorNumber,
        ownerId: ownerId,
        amount: amount,
        adjustmentType: adjustmentType,
        effectiveFrom: effectiveFrom,
      );

      state = const AsyncData(null);

      return rentRates;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // CHANGE PROPERTY RENT
  // ============================================================
  //
  // amount = adjustment amount
  //
  // increase:
  // current rent + amount
  //
  // decrease:
  // current rent - amount
  //
  // ============================================================

  Future<List<RentRate>?> changePropertyRent({
    required String propertyId,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    state = const AsyncLoading();

    try {
      final rentRates = await _changePropertyRent(
        propertyId: propertyId,
        ownerId: ownerId,
        amount: amount,
        adjustmentType: adjustmentType,
        effectiveFrom: effectiveFrom,
      );

      state = const AsyncData(null);

      return rentRates;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    state = const AsyncData(null);
  }
}