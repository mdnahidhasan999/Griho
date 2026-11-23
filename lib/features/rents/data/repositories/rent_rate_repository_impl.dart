// noinspection SpellCheckingInspection
import '../../../units/domain/entities/unit.dart';
import '../../../units/domain/repositories/unit_repository.dart';
import '../../domain/entities/create_rent_rate_request.dart';
import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/repositories/rent_rate_repository.dart';
import '../datasources/rent_rate_datasource.dart';
import '../models/rent_rate_model.dart';

class RentRateRepositoryImpl implements RentRateRepository {
  final RentRateDataSource _dataSource;
  final UnitRepository _unitRepository;

  RentRateRepositoryImpl({
    required this._dataSource,
    required this._unitRepository,
  });

  @override
  Future<RentRate> createInitialRentRate(CreateRentRateRequest request) {
    final now = DateTime.now();

    final rentRate = RentRateModel(
      id: '',
      ownerId: request.ownerId.trim(),
      propertyId: request.propertyId.trim(),
      unitId: request.unitId.trim(),
      amount: request.amount,
      effectiveFrom: request.effectiveFrom,
      effectiveTo: null,
      source: request.source,
      previousRentRateId: request.previousRentRateId,
      nextRentRateId: null,
      createdAt: now,
      updatedAt: now,
    );

    return _dataSource.createInitialRentRate(rentRate: rentRate);
  }

  @override
  Future<RentRate?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  }) {
    return _dataSource.getCurrentRentRate(unitId: unitId, ownerId: ownerId);
  }

  @override
  Future<RentRate?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  }) {
    return _dataSource.getRentRateApplicableAt(
      unitId: unitId,
      ownerId: ownerId,
      effectiveAt: effectiveAt,
    );
  }

  @override
  Future<List<RentRate>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) {
    return _dataSource.getRentRateHistoryByUnitId(
      unitId: unitId,
      ownerId: ownerId,
    );
  }

  /// Fetches floor units + property rates in 2 parallel queries instead of N+1 queries.
  @override
  Future<List<RentRate>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (floorNumber < 1) {
      throw ArgumentError('Floor number must be at least 1.');
    }

    final results = await Future.wait<dynamic>([
      _unitRepository.getUnitsByFloor(
        propertyId: normalizedPropertyId,
        floorNumber: floorNumber,
      ),
      _dataSource.getCurrentRentRatesByProperty(
        propertyId: normalizedPropertyId,
        ownerId: normalizedOwnerId,
      ),
    ]);

    final units = results[0] as List<Unit>;
    if (units.isEmpty) {
      return [];
    }

    final propertyRates = results[1] as List<RentRateModel>;
    final rateByUnitId = {for (final rate in propertyRates) rate.unitId: rate};

    final currentRates = <RentRate>[];
    for (final unit in units) {
      final currentRate = rateByUnitId[unit.id];
      if (currentRate == null) {
        throw StateError(
          'No current rent rate exists for unit ${unit.unitNumber}.',
        );
      }
      currentRates.add(currentRate);
    }

    return currentRates;
  }

  /// Fetches property units + property rates in 2 parallel queries instead of N+1 queries.
  @override
  Future<List<RentRate>> getCurrentRentRatesByProperty({
    required String propertyId,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    final results = await Future.wait<dynamic>([
      _unitRepository.getUnitsByPropertyId(normalizedPropertyId),
      _dataSource.getCurrentRentRatesByProperty(
        propertyId: normalizedPropertyId,
        ownerId: normalizedOwnerId,
      ),
    ]);

    final units = results[0] as List<Unit>;
    if (units.isEmpty) {
      return [];
    }

    final propertyRates = results[1] as List<RentRateModel>;
    final rateByUnitId = {for (final rate in propertyRates) rate.unitId: rate};

    final currentRates = <RentRate>[];
    for (final unit in units) {
      final currentRate = rateByUnitId[unit.id];
      if (currentRate == null) {
        throw StateError(
          'No current rent rate exists for unit ${unit.unitNumber}.',
        );
      }
      currentRates.add(currentRate);
    }

    return currentRates;
  }

  @override
  Future<RentRate> changeUnitRent({
    required String unitId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) {
    return _dataSource.changeUnitRent(
      unitId: unitId,
      ownerId: ownerId,
      amount: amount,
      effectiveFrom: effectiveFrom,
    );
  }

  @override
  Future<List<RentRate>> changeFloorRent({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (floorNumber < 1) {
      throw ArgumentError('Floor number must be at least 1.');
    }
    if (amount <= 0) {
      throw ArgumentError('Rent adjustment amount must be greater than zero.');
    }

    final currentRates = await getCurrentRentRatesByFloor(
      propertyId: normalizedPropertyId,
      floorNumber: floorNumber,
      ownerId: normalizedOwnerId,
    );

    if (currentRates.isEmpty) {
      return [];
    }

    return _dataSource.changeFloorRent(
      currentRates: currentRates.map((rate) => rate as RentRateModel).toList(),
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );
  }

  @override
  Future<List<RentRate>> changePropertyRent({
    required String propertyId,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError('Rent adjustment amount must be greater than zero.');
    }

    final currentRates = await getCurrentRentRatesByProperty(
      propertyId: normalizedPropertyId,
      ownerId: normalizedOwnerId,
    );

    if (currentRates.isEmpty) {
      return [];
    }

    return _dataSource.changePropertyRent(
      currentRates: currentRates.map((rate) => rate as RentRateModel).toList(),
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );
  }
}
