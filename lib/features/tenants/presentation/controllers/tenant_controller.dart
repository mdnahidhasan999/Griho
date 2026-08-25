import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/current_user_service.dart';

import '../../data/datasources/tenant_data_source.dart';
import '../../data/repositories/tenant_repository_impl.dart';

import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';

import '../../domain/usecases/create_tenant.dart';
import '../../domain/usecases/delete_tenant.dart';
import '../../domain/usecases/get_tenant.dart';
import '../../domain/usecases/get_tenant_by_unit_id.dart';
import '../../domain/usecases/update_tenant.dart';

// ================================================================
// TENANT REPOSITORY
// ================================================================

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  final dataSource = TenantDataSource();

  final currentUserService = CurrentUserService();

  return TenantRepositoryImpl(
    dataSource: dataSource,
    currentUserService: currentUserService,
  );
});

// ================================================================
// CREATE TENANT
// ================================================================

final createTenantProvider = Provider<CreateTenant>((ref) {
  return CreateTenant(
    repository: ref.read(
      tenantRepositoryProvider,
    ),
  );
});

// ================================================================
// UPDATE TENANT
// ================================================================

final updateTenantProvider = Provider<UpdateTenant>((ref) {
  return UpdateTenant(
    repository: ref.read(
      tenantRepositoryProvider,
    ),
  );
});

// ================================================================
// DELETE TENANT
// ================================================================

final deleteTenantProvider = Provider<DeleteTenant>((ref) {
  return DeleteTenant(
    repository: ref.read(
      tenantRepositoryProvider,
    ),
  );
});

// ================================================================
// CONTROLLER
// ================================================================

class TenantController extends StateNotifier<AsyncValue<Tenant?>> {
  final CreateTenant _createTenant;
  final UpdateTenant _updateTenant;
  final DeleteTenant _deleteTenant;

  TenantController({
    required this._createTenant,
    required this._updateTenant,
    required this._deleteTenant,
  }) : super(const AsyncData(null));

  // ==============================================================
  // CREATE
  // ==============================================================

  Future<Tenant?> createTenant(CreateTenantRequest request,) async {
    state = const AsyncLoading();

    try {
      final tenant = await _createTenant(request);

      state = AsyncData(tenant);

      return tenant;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // UPDATE
  // ==============================================================

  Future<Tenant?> updateTenant(Tenant tenant,) async {
    state = const AsyncLoading();

    try {
      final updatedTenant = await _updateTenant(tenant);

      state = AsyncData(updatedTenant);

      return updatedTenant;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // DELETE
  // ==============================================================

  Future<bool> deleteTenant(String tenantId,) async {
    state = const AsyncLoading();

    try {
      await _deleteTenant(tenantId);

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  // ==============================================================
  // CLEAR
  // ==============================================================

  void clear() {
    state = const AsyncData(null);
  }
}

// ================================================================
// PROVIDER
// ================================================================

final tenantControllerProvider =
StateNotifierProvider<TenantController, AsyncValue<Tenant?>>(
      (ref) {
    return TenantController(
      createTenant: ref.read(
        createTenantProvider,
      ),
      updateTenant: ref.read(
        updateTenantProvider,
      ),
      deleteTenant: ref.read(
        deleteTenantProvider,
      ),
    );
  },
);

// ================================================================
// GET TENANT
// ================================================================

final getTenantProvider = Provider<GetTenant>((ref) {
  return GetTenant(
    repository: ref.read(
      tenantRepositoryProvider,
    ),
  );
});


// ================================================================
// GET TENANT BY UNIT
// ================================================================

final getTenantByUnitIdProvider =
Provider<GetTenantByUnitId>((ref) {
  final repository = ref.read(tenantRepositoryProvider);

  return GetTenantByUnitId(
    repository,
  );
});