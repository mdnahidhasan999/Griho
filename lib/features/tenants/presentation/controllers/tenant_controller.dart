// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';
import '../../data/datasources/tenant_data_source.dart';
import '../../data/repositories/tenant_repository_impl.dart';
import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/usecases/cleanup_duplicate_active_tenants.dart';
import '../../domain/usecases/create_tenant.dart';
import '../../domain/usecases/delete_tenant.dart';
import '../../domain/usecases/end_tenancy.dart';
import '../../domain/usecases/get_active_tenants_by_unit_id.dart';
import '../../domain/usecases/get_tenant.dart';
import '../../domain/usecases/get_tenant_by_unit_id.dart';
import '../../domain/usecases/link_tenant_account.dart';
import '../../domain/usecases/start_new_tenancy.dart';
import '../../domain/usecases/update_tenant.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepositoryImpl(
    dataSource: TenantDataSource(),
    currentUserService: CurrentUserService(),
  );
});

final createTenantProvider = Provider<CreateTenant>((ref) {
  return CreateTenant(repository: ref.read(tenantRepositoryProvider));
});

final updateTenantProvider = Provider<UpdateTenant>((ref) {
  return UpdateTenant(repository: ref.read(tenantRepositoryProvider));
});

final deleteTenantProvider = Provider<DeleteTenant>((ref) {
  return DeleteTenant(repository: ref.read(tenantRepositoryProvider));
});

final endTenancyProvider = Provider<EndTenancy>((ref) {
  return EndTenancy(repository: ref.read(tenantRepositoryProvider));
});

final startNewTenancyProvider = Provider<StartNewTenancy>((ref) {
  return StartNewTenancy(repository: ref.read(tenantRepositoryProvider));
});

final getTenantProvider = Provider<GetTenant>((ref) {
  return GetTenant(repository: ref.read(tenantRepositoryProvider));
});

final getTenantByUnitIdProvider = Provider<GetTenantByUnitId>((ref) {
  return GetTenantByUnitId(ref.read(tenantRepositoryProvider));
});

final getActiveTenantsByUnitIdProvider = Provider<GetActiveTenantsByUnitId>((
  ref,
) {
  return GetActiveTenantsByUnitId(ref.read(tenantRepositoryProvider));
});

final cleanupDuplicateActiveTenantsProvider =
    Provider<CleanupDuplicateActiveTenants>((ref) {
      return CleanupDuplicateActiveTenants(ref.read(tenantRepositoryProvider));
    });

final linkTenantAccountProvider = Provider<LinkTenantAccount>((ref) {
  return LinkTenantAccount(repository: ref.read(tenantRepositoryProvider));
});

class TenantController extends Notifier<AsyncValue<Tenant?>> {
  late final CreateTenant _createTenant;
  late final UpdateTenant _updateTenant;
  late final DeleteTenant _deleteTenant;
  late final EndTenancy _endTenancy;
  late final LinkTenantAccount _linkTenantAccount;
  late final StartNewTenancy _startNewTenancy;

  @override
  AsyncValue<Tenant?> build() {
    _createTenant = ref.read(createTenantProvider);
    _updateTenant = ref.read(updateTenantProvider);
    _deleteTenant = ref.read(deleteTenantProvider);
    _endTenancy = ref.read(endTenancyProvider);
    _linkTenantAccount = ref.read(linkTenantAccountProvider);
    _startNewTenancy = ref.read(startNewTenancyProvider);
    return const AsyncData(null);
  }

  Future<Tenant?> createTenant(CreateTenantRequest request) async {
    state = const AsyncLoading();

    try {
      final tenant = await _createTenant(request);
      state = AsyncData(tenant);
      return tenant;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<Tenant?> updateTenant(Tenant tenant) async {
    state = const AsyncLoading();

    try {
      final updatedTenant = await _updateTenant(tenant);
      state = AsyncData(updatedTenant);
      return updatedTenant;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<Tenant?> linkTenantAccount({
    required String tenantId,
    required String userId,
  }) async {
    state = const AsyncLoading();

    try {
      final linkedTenant = await _linkTenantAccount(
        tenantId: tenantId,
        userId: userId,
      );
      state = AsyncData(linkedTenant);
      return linkedTenant;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<Tenant?> endTenancy(String tenantId) async {
    state = const AsyncLoading();

    try {
      final endedTenant = await _endTenancy(tenantId);
      state = AsyncData(endedTenant);
      return endedTenant;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<Tenant?> startNewTenancy({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required double amount,
  }) async {
    state = const AsyncLoading();

    try {
      final startedTenant = await _startNewTenancy(
        tenantId: tenantId,
        propertyId: propertyId,
        unitId: unitId,
        amount: amount,
      );
      state = AsyncData(startedTenant);
      return startedTenant;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<bool> deleteTenant(String tenantId) async {
    state = const AsyncLoading();

    try {
      await _deleteTenant(tenantId);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final tenantControllerProvider =
    NotifierProvider<TenantController, AsyncValue<Tenant?>>(
      TenantController.new,
    );
