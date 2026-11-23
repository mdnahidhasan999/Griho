// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_rent_rate_request.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/usecases/change_floor_rent.dart';
import '../../domain/usecases/change_property_rent.dart';
import '../../domain/usecases/change_unit_rent.dart';
import '../../domain/usecases/create_initial_rent_rate.dart';
import '../providers/rent_rate_provider.dart';

class RentRateController extends Notifier<AsyncValue<void>> {
  late final CreateInitialRentRate _createInitialRentRate;
  late final ChangeUnitRent _changeUnitRent;
  late final ChangeFloorRent _changeFloorRent;
  late final ChangePropertyRent _changePropertyRent;

  @override
  AsyncValue<void> build() {
    _createInitialRentRate = ref.read(createInitialRentRateProvider);
    _changeUnitRent = ref.read(changeUnitRentProvider);
    _changeFloorRent = ref.read(changeFloorRentProvider);
    _changePropertyRent = ref.read(changePropertyRentProvider);
    return const AsyncData(null);
  }

  Future<RentRate?> createInitialRentRate({
    required CreateRentRateRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final rentRate = await _createInitialRentRate(request);
      state = const AsyncData(null);
      return rentRate;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

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
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

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
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

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
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
