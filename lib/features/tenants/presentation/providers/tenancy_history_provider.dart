import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/tenancy_history_datasource.dart';
import '../../data/repositories/tenancy_history_repository_impl.dart';
import '../../domain/entities/repositories/tenancy_history_repository.dart';
import '../../domain/entities/tenancy_history.dart';
import '../../domain/usecases/get_my_tenancy_history.dart';
import '../../domain/usecases/get_tenant_history.dart';
import '../../domain/usecases/get_unit_history.dart';

final tenancyHistoryDataSourceProvider =
Provider<TenancyHistoryDataSource>((ref) {
  return TenancyHistoryDataSource();
});

final tenancyHistoryRepositoryProvider =
Provider<TenancyHistoryRepository>((ref) {
  return TenancyHistoryRepositoryImpl(
    dataSource: ref.read(
      tenancyHistoryDataSourceProvider,
    ),
  );
});

// ============================================================================
// TENANT HISTORY
// ============================================================================

final getTenantHistoryProvider =
Provider<GetTenantHistory>((ref) {
  return GetTenantHistory(
    repository: ref.read(
      tenancyHistoryRepositoryProvider,
    ),
  );
});

final tenantHistoryProvider = FutureProvider.family<
    List<TenancyHistory>,
    ({String tenantId, String ownerId})>(
      (ref, args) async {
    final getTenantHistory = ref.read(
      getTenantHistoryProvider,
    );

    return getTenantHistory(
      tenantId: args.tenantId,
      ownerId: args.ownerId,
    );
  },
);

// ============================================================================
// UNIT HISTORY
// ============================================================================

final getUnitHistoryProvider =
Provider<GetUnitHistory>((ref) {
  return GetUnitHistory(
    repository: ref.read(
      tenancyHistoryRepositoryProvider,
    ),
  );
});

final unitHistoryProvider = FutureProvider.family<
    List<TenancyHistory>,
    ({String unitId, String ownerId})>(
      (ref, args) async {
    final getUnitHistory = ref.read(
      getUnitHistoryProvider,
    );

    return getUnitHistory(
      unitId: args.unitId,
      ownerId: args.ownerId,
    );
  },
);

// ============================================================================
// MY TENANCY HISTORY — TENANT SIDE
// ============================================================================

final getMyTenancyHistoryProvider =
Provider<GetMyTenancyHistory>((ref) {
  return GetMyTenancyHistory(
    repository: ref.read(
      tenancyHistoryRepositoryProvider,
    ),
  );
});

final myTenancyHistoryProvider =
FutureProvider.family<
    List<TenancyHistory>,
    String>(
      (ref, tenantUserId) async {
    final getMyTenancyHistory = ref.read(
      getMyTenancyHistoryProvider,
    );

    return getMyTenancyHistory(
      tenantUserId: tenantUserId,
    );
  },
);