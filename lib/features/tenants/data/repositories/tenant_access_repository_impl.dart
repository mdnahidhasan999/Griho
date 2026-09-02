import '../../domain/entities/repositories/tenant_access_repository.dart';
import '../../domain/entities/tenant_access.dart';
import '../datasources/tenant_access_data_source.dart';
import '../models/tenant_access_model.dart';

class TenantAccessRepositoryImpl
    implements TenantAccessRepository {
  final TenantAccessDataSource _dataSource;

  const TenantAccessRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<TenantAccess?> getTenantAccessByUserId(
      String userId,
      ) async {
    return _dataSource.getTenantAccessByUserId(
      userId,
    );
  }

  @override
  Future<void> createOrUpdateTenantAccess(
      TenantAccess access,
      ) async {
    final model = TenantAccessModel.fromEntity(
      access,
    );

    await _dataSource.createOrUpdateTenantAccess(
      model,
    );
  }

  @override
  Future<void> deleteTenantAccess(
      String userId,
      ) async {
    await _dataSource.deleteTenantAccess(
      userId,
    );
  }
}