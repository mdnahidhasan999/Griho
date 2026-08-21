import '../create_tenant_request.dart';
import '../tenant.dart';

abstract interface class TenantRepository {
  Future<Tenant?> getTenantById(String tenantId);

  Future<List<Tenant>> getTenantsByPropertyId(String propertyId);

  Future<Tenant?> getTenantByUnitId(String unitId);

  Future<Tenant> createTenant(CreateTenantRequest request);

  Future<Tenant> updateTenant(Tenant tenant);

  Future<void> deleteTenant(String tenantId);
}
