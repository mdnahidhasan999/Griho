import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/create_or_update_tenant_access.dart';
import '../../domain/usecases/delete_tenant_access.dart';
import '../../domain/usecases/get_tenant_access.dart';
import 'tenant_access_provider.dart';

final getTenantAccessProvider = Provider<GetTenantAccess>((ref) {
  final repository = ref.read(tenantAccessRepositoryProvider);

  return GetTenantAccess(repository);
});

final createOrUpdateTenantAccessProvider = Provider<CreateOrUpdateTenantAccess>(
  (ref) {
    final repository = ref.read(tenantAccessRepositoryProvider);

    return CreateOrUpdateTenantAccess(repository);
  },
);

final deleteTenantAccessProvider = Provider<DeleteTenantAccess>((ref) {
  final repository = ref.read(tenantAccessRepositoryProvider);

  return DeleteTenantAccess(repository);
});
