import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';

import '../datasources/tenant_data_source.dart';
import '../models/tenant_model.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantDataSource _dataSource;
  final CurrentUserService _currentUserService;

  const TenantRepositoryImpl({
    required this._dataSource,
    required this._currentUserService,
  });

  // ============================================================
  // GET TENANT BY ID
  // ============================================================

  @override
  Future<Tenant?> getTenantById(String tenantId,) {
    return _dataSource.getTenantById(
      tenantId,
    );
  }

  // ============================================================
// GET TENANTS BY PROPERTY
// CURRENT OWNER ONLY
// ============================================================

  @override
  Future<List<Tenant>> getTenantsByPropertyId(String propertyId,) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.getTenantsByPropertyId(
      propertyId: propertyId,
      ownerId: ownerId,
    );
  }

  // ============================================================
  // GET TENANT BY UNIT
  // ============================================================

  @override
  Future<Tenant?> getTenantByUnitId(String unitId,) {
    return _dataSource.getTenantByUnitId(
      unitId,
    );
  }

  // ============================================================
  // SEARCH TENANTS
  // ============================================================

  @override
  Future<List<Tenant>> searchTenants(String search,) {
    return _dataSource.searchTenants(
      search,
    );
  }

  // ============================================================
  // FIND TENANT BY PHONE
  // CURRENT OWNER ONLY
  // ============================================================

  @override
  Future<Tenant?> findTenantByPhone({
    required String phone,
    required String ownerId,
  }) {
    return _dataSource.findTenantByPhone(
      phone: phone,
      ownerId: ownerId,
    );
  }

  // ============================================================
  // CREATE TENANT
  // ============================================================

  @override
  Future<Tenant> createTenant(CreateTenantRequest request,) async {
    final now = DateTime.now();

    final documentId =
    DateTime
        .now()
        .microsecondsSinceEpoch
        .toString();

    final ownerId = _currentUserService.requiredUid;

    final tenant = TenantModel(
      id: documentId,
      ownerId: ownerId,
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

    return _dataSource.createTenant(
      tenant: tenant,
    );
  }

  // ============================================================
  // UPDATE TENANT
  // ============================================================

  @override
  Future<Tenant> updateTenant(Tenant tenant,) async {
    final model = TenantModel.fromEntity(
      tenant,
    );

    return _dataSource.updateTenant(
      model,
    );
  }

  // ============================================================
  // DELETE TENANT
  // ============================================================

  @override
  Future<void> deleteTenant(String tenantId,) {
    return _dataSource.deleteTenant(
      tenantId,
    );
  }
}