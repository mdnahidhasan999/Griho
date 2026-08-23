import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/tenant_data_source.dart';
import '../../data/repositories/tenant_repository_impl.dart';
import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/usecases/create_tenant.dart';
import '../../domain/usecases/delete_tenant.dart';
import '../../domain/usecases/update_tenant.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  final dataSource = TenantDataSource();

  return TenantRepositoryImpl(dataSource: dataSource);
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

class TenantController extends StateNotifier<AsyncValue<Tenant?>> {
  final CreateTenant _createTenant;
  final UpdateTenant _updateTenant;
  final DeleteTenant _deleteTenant;

  TenantController({
    required this._createTenant,
    required this._updateTenant,
    required this._deleteTenant,
  }) : super(const AsyncData(null));

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
    StateNotifierProvider<TenantController, AsyncValue<Tenant?>>((ref) {
      return TenantController(
        createTenant: ref.read(createTenantProvider),
        updateTenant: ref.read(updateTenantProvider),
        deleteTenant: ref.read(deleteTenantProvider),
      );
    });
