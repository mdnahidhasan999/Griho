import '../entities/create_rent_rate_request.dart';
import '../entities/rent_rate.dart';

abstract class RentRateRepository {
  Future<RentRate> createInitialRentRate(
      CreateRentRateRequest request,
      );

  Future<RentRate?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  });

  Future<RentRate?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  });

  Future<List<RentRate>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  Future<List<RentRate>> getRentRateHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  });

  Future<List<RentRate>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  });

  Future<RentRate> changeUnitRent({
    required String unitId,
    required String tenantId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });

  Future<List<RentRate>> changeFloorRent({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });
}