import '../../domain/entities/create_rent_rate_request.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/repositories/rent_rate_repository.dart';
import '../../../units/domain/repositories/unit_repository.dart';
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
  Future<RentRate> createInitialRentRate(
      CreateRentRateRequest request,
      ) {
    final now = DateTime.now();

    final rentRate = RentRateModel(
      id: '',
      ownerId: request.ownerId.trim(),
      propertyId: request.propertyId.trim(),
      unitId: request.unitId.trim(),
      tenantId: request.tenantId.trim(),
      tenantUserId: request.tenantUserId,
      amount: request.amount,
      effectiveFrom: request.effectiveFrom,
      effectiveTo: null,
      source: request.source,
      createdAt: now,
      updatedAt: now,
    );

    return _dataSource.createInitialRentRate(
      rentRate: rentRate,
    );
  }

  @override
  Future<RentRate?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  }) {
    return _dataSource.getCurrentRentRate(
      unitId: unitId,
      ownerId: ownerId,
    );
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

  @override
  Future<List<RentRate>> getRentRateHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) {
    return _dataSource.getRentRateHistoryByTenantId(
      tenantId: tenantId,
      ownerId: ownerId,
    );
  }

  @override
  Future<List<RentRate>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) {
    return _dataSource.getCurrentRentRatesByFloor(
      propertyId: propertyId,
      floorNumber: floorNumber,
      ownerId: ownerId,
    );
  }

  @override
  Future<RentRate> changeUnitRent({
    required String unitId,
    required String tenantId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) {
    return _dataSource.changeUnitRent(
      unitId: unitId,
      tenantId: tenantId,
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
    required DateTime effectiveFrom,
  }) async {
    if (propertyId.trim().isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (ownerId.trim().isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final units =
    await _unitRepository.getOccupiedUnitsByFloor(
      propertyId: propertyId,
      floorNumber: floorNumber,
    );

    if (units.isEmpty) {
      return [];
    }

    final currentRates = <RentRateModel>[];

    for (final unit in units) {
      final currentRate =
      await _dataSource.getCurrentRentRate(
        unitId: unit.id,
        ownerId: ownerId,
      );

      if (currentRate == null) {
        throw StateError(
          'No current rent rate exists for occupied unit ${unit.id}.',
        );
      }

      currentRates.add(currentRate);
    }

    return _dataSource.changeFloorRent(
      currentRates: currentRates,
      amount: amount,
      effectiveFrom: effectiveFrom,
    );
  }
}