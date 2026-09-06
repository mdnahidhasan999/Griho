import '../tenancy_history.dart';

abstract class TenancyHistoryRepository {
  Future<List<TenancyHistory>> getHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  });

  Future<List<TenancyHistory>> getHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  Future<List<TenancyHistory>> getHistoryByTenantUserId({
    required String tenantUserId,
  });
}