import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';
import '../../data/datasources/property_datasource.dart';
import '../../data/repositories/property_repository_impl.dart';
import '../../domain/repositories/property_repository.dart';

final currentUserServiceProvider = Provider<CurrentUserService>((ref) {
  return CurrentUserService();
});

final propertyDataSourceProvider = Provider<PropertyDataSource>((ref) {
  return PropertyDataSource();
});

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return PropertyRepositoryImpl(
    dataSource: ref.watch(propertyDataSourceProvider),
    currentUserService: ref.watch(currentUserServiceProvider),
  );
});