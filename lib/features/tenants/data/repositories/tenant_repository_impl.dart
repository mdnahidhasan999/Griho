import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';

import '../datasources/tenant_data_source.dart';
import '../models/tenant_model.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantDataSource _dataSource;
  final CurrentUserService _currentUserService;

  const TenantRepositoryImpl({
    required this._dataSource,
    required this._currentUserService,
  });

  // ==========================================================================
  // GET TENANT BY ID
  // ==========================================================================

  @override
  Future<Tenant?> getTenantById(String tenantId) {
    return _dataSource.getTenantById(tenantId);
  }

  // ==========================================================================
  // GET TENANT BY USER ID
  // CURRENT TENANT ONLY
  // ==========================================================================

  @override
  Future<Tenant?> getTenantByUserId(String userId) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return Future.value(null);
    }

    return _dataSource.getTenantByUserId(normalizedUserId);
  }

  // ==========================================================================
  // GET TENANTS BY PROPERTY
  // CURRENT OWNER ONLY
  // ==========================================================================

  @override
  Future<List<Tenant>> getTenantsByPropertyId(String propertyId) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.getTenantsByPropertyId(
      propertyId: propertyId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // GET TENANT BY UNIT
  // CURRENT OWNER ONLY
  // ==========================================================================

  @override
  Future<Tenant?> getTenantByUnitId(String unitId) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.getTenantByUnitId(unitId: unitId, ownerId: ownerId);
  }

  // ==========================================================================
  // GET ACTIVE TENANTS BY UNIT
  // CURRENT OWNER ONLY
  // ==========================================================================

  @override
  Future<List<Tenant>> getActiveTenantsByUnitId(String unitId) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.getActiveTenantsByUnitId(
      unitId: unitId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY GRIHO ID
  // ==========================================================================

  @override
  Future<TenantSearchResult?> searchRegisteredTenantByPublicId(
      String publicId,) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.searchRegisteredTenantByPublicId(
      publicId: publicId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY PHONE
  // ==========================================================================

  @override
  Future<TenantSearchResult?> searchRegisteredTenantByPhone(String phone) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.searchRegisteredTenantByPhone(
      phone: phone,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // FIND TENANT BY PHONE
  // ==========================================================================

  @override
  Future<Tenant?> findTenantByPhone({
    required String phone,
    required String ownerId,
  }) {
    return _dataSource.findTenantByPhone(phone: phone, ownerId: ownerId);
  }

  // ==========================================================================
  // CREATE TENANT
  // ==========================================================================

  @override
  Future<Tenant> createTenant(CreateTenantRequest request) async {
    final ownerId = _currentUserService.requiredUid;

    final name = request.name.trim();
    final phone = request.phone.trim();

    if (name.isEmpty) {
      throw ArgumentError('Tenant name cannot be empty.');
    }

    if (phone.isEmpty) {
      throw ArgumentError('Tenant phone number cannot be empty.');
    }

    final documentId = DateTime
        .now()
        .microsecondsSinceEpoch
        .toString();

    final now = DateTime.now();

    final userId = request.userId?.trim();

    final email = request.email?.trim();

    final nidNumber = request.nidNumber?.trim();

    final tenant = TenantModel(
      id: documentId,
      ownerId: ownerId,
      userId: userId == null || userId.isEmpty ? null : userId,
      propertyId: request.propertyId.trim(),
      unitId: request.unitId.trim(),
      name: name,
      phone: phone,
      email: email == null || email.isEmpty ? null : email,
      nidNumber: nidNumber == null || nidNumber.isEmpty ? null : nidNumber,
      status: request.status,
      accountStatus: userId != null && userId.isNotEmpty
          ? TenantAccountStatus.registered
          : TenantAccountStatus.notRegistered,
      confirmationStatus: TenantConfirmationStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    if (tenant.propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (tenant.unitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    return _dataSource.createTenant(tenant: tenant);
  }

  // ==========================================================================
  // UPDATE TENANT
  // ==========================================================================

  @override
  Future<Tenant> updateTenant(Tenant tenant) async {
    final ownerId = _currentUserService.requiredUid;

    if (tenant.ownerId != ownerId) {
      throw StateError('You are not authorized to update this tenant.');
    }

    final model = TenantModel.fromEntity(tenant);

    return _dataSource.updateTenant(model);
  }

  // ==========================================================================
  // LINK TENANT ACCOUNT
  // ==========================================================================

  @override
  Future<Tenant> linkTenantAccount({
    required String tenantId,
    required String userId,
  }) {
    final currentUserId = _currentUserService.requiredUid;

    if (currentUserId != userId.trim()) {
      throw StateError('You can only link your own account.');
    }

    return _dataSource.linkTenantAccount(
      tenantId: tenantId,
      userId: currentUserId,
    );
  }

  // ==========================================================================
  // CLEANUP DUPLICATE ACTIVE TENANTS
  // ==========================================================================

  @override
  Future<void> cleanupDuplicateActiveTenants({
    required String unitId,
    required String ownerId,
    required String keepTenantId,
  }) {
    final currentUserId = _currentUserService.requiredUid;

    if (currentUserId != ownerId) {
      throw StateError('You are not authorized to clean up these tenants.');
    }

    return _dataSource.cleanupDuplicateActiveTenants(
      unitId: unitId,
      ownerId: ownerId,
      keepTenantId: keepTenantId,
    );
  }

  // ==========================================================================
  // END TENANCY
  // ==========================================================================

  @override
  Future<Tenant> endTenancy(String tenantId) async {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.endTenancy(tenantId: tenantId, ownerId: ownerId);
  }

  @override
  Future<Tenant> startNewTenancy({
    required String tenantId,
    required String propertyId,
    required String unitId,
  }) async {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.startNewTenancy(
      tenantId: tenantId,
      propertyId: propertyId,
      unitId: unitId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // DELETE TENANT
  // ==========================================================================

  @override
  Future<void> deleteTenant(String tenantId) async {
    final tenant = await _dataSource.getTenantById(tenantId);

    if (tenant == null) {
      return;
    }

    final currentUserId = _currentUserService.requiredUid;

    if (tenant.ownerId != currentUserId) {
      throw StateError('You are not authorized to delete this tenant.');
    }

    await _dataSource.deleteTenant(tenantId);
  }
}
