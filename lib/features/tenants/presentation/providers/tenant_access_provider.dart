import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/tenant_access_data_source.dart';
import '../../data/repositories/tenant_access_repository_impl.dart';
import '../../domain/entities/repositories/tenant_access_repository.dart';

final tenantAccessDataSourceProvider = Provider<TenantAccessDataSource>((ref) {
  return TenantAccessDataSource();
});

final tenantAccessRepositoryProvider = Provider<TenantAccessRepository>((ref) {
  final dataSource = ref.read(tenantAccessDataSourceProvider);

  return TenantAccessRepositoryImpl(dataSource: dataSource);
});
