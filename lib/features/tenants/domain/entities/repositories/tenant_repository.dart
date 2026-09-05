import '../create_tenant_request.dart';
import '../tenant.dart';
import '../tenant_search_result.dart';

abstract class TenantRepository {
  Future<Tenant?> getTenantById(String tenantId);

  Future<Tenant?> getTenantByUserId(String userId);

  Future<List<Tenant>> getTenantsByPropertyId(String propertyId);

  Future<Tenant?> getTenantByUnitId(String unitId);

  Future<List<Tenant>> getActiveTenantsByUnitId(String unitId);

  // ============================================================
  // SEARCH REGISTERED TENANT
  // ============================================================

  Future<TenantSearchResult?> searchRegisteredTenantByPublicId(String publicId);

  Future<TenantSearchResult?> searchRegisteredTenantByPhone(String phone);

  // ============================================================
  // FIND TENANT BY PHONE
  // ============================================================

  Future<Tenant?> findTenantByPhone({
    required String phone,
    required String ownerId,
  });

  // ============================================================
  // CREATE TENANT
  // ============================================================

  Future<Tenant> createTenant(CreateTenantRequest request);

  // ============================================================
  // UPDATE TENANT
  // ============================================================

  Future<Tenant> updateTenant(Tenant tenant);

  // ============================================================
  // LINK TENANT ACCOUNT
  // ============================================================

  Future<Tenant> linkTenantAccount({
    required String tenantId,
    required String userId,
  });

  // ============================================================
  // CLEANUP DUPLICATE ACTIVE TENANTS
  // ============================================================

  Future<void> cleanupDuplicateActiveTenants({
    required String unitId,
    required String ownerId,
    required String keepTenantId,
  });

  // ============================================================
  // END TENANCY
  // ============================================================

  Future<Tenant> endTenancy(String tenantId);

  Future<Tenant> startNewTenancy({
    required String tenantId,
    required String propertyId,
    required String unitId,
  });

  // ============================================================
  // DELETE TENANT
  // ============================================================

  Future<void> deleteTenant(String tenantId);
}
