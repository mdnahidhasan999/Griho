import '../create_tenant_request.dart';
import '../tenant.dart';

abstract class TenantRepository {
  Future<Tenant?> getTenantById(String tenantId);

  Future<List<Tenant>> getTenantsByPropertyId(String propertyId);

  Future<Tenant?> getTenantByUnitId(String unitId);

  Future<List<Tenant>> searchTenants(String search);

  // নতুন
  Future<Tenant?> findTenantByPhone({
    required String phone,
    required String ownerId,
  });

  Future<Tenant> createTenant(CreateTenantRequest request);

  Future<Tenant> updateTenant(Tenant tenant);

  Future<void> deleteTenant(String tenantId);
}