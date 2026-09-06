import 'package:griho/features/tenants/domain/entities/repositories/tenancy_history_repository.dart';
import 'package:griho/features/tenants/domain/entities/tenancy_history.dart';
import '../datasources/tenancy_history_datasource.dart';

class TenancyHistoryRepositoryImpl
    implements TenancyHistoryRepository {
  final TenancyHistoryDataSource _dataSource;

  const TenancyHistoryRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<List<TenancyHistory>> getHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) async {
    return _dataSource.getHistoryByTenantId(
      tenantId: tenantId,
      ownerId: ownerId,
    );
  }

  @override
  Future<List<TenancyHistory>> getHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    return _dataSource.getHistoryByUnitId(
      unitId: unitId,
      ownerId: ownerId,
    );
  }

  @override
  Future<List<TenancyHistory>> getHistoryByTenantUserId({
    required String tenantUserId,
  }) async {
    return _dataSource.getHistoryByTenantUserId(
      tenantUserId: tenantUserId,
    );
  }
}