import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';
import '../datasources/tenant_data_source.dart';
import '../models/tenant_model.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantDataSource _dataSource;

  const TenantRepositoryImpl({required this._dataSource});

  @override
  Future<Tenant?> getTenantById(String tenantId) {
    return _dataSource.getTenantById(tenantId);
  }

  @override
  Future<List<Tenant>> getTenantsByPropertyId(String propertyId) {
    return _dataSource.getTenantsByPropertyId(propertyId);
  }

  @override
  Future<Tenant?> getTenantByUnitId(String unitId) {
    return _dataSource.getTenantByUnitId(unitId);
  }

  @override
  Future<Tenant> createTenant(CreateTenantRequest request) async {
    final now = DateTime.now();

    final documentId = DateTime.now().microsecondsSinceEpoch.toString();

    final tenant = TenantModel(
      id: documentId,
      userId: request.userId,
      propertyId: request.propertyId,
      unitId: request.unitId,
      name: request.name,
      phone: request.phone,
      email: request.email,
      nidNumber: request.nidNumber,
      status: request.status,
      createdAt: now,
      updatedAt: now,
    );

    return _dataSource.createTenant(tenant: tenant);
  }

  @override
  Future<Tenant> updateTenant(Tenant tenant) async {
    final model = TenantModel.fromEntity(tenant);

    return _dataSource.updateTenant(model);
  }

  @override
  Future<void> deleteTenant(String tenantId) {
    return _dataSource.deleteTenant(tenantId);
  }
}
