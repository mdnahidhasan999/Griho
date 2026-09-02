import '../tenant_access.dart';

abstract interface class TenantAccessRepository {
  Future<TenantAccess?> getTenantAccessByUserId(
      String userId,
      );

  Future<void> createOrUpdateTenantAccess(
      TenantAccess access,
      );

  Future<void> deleteTenantAccess(
      String userId,
      );
}