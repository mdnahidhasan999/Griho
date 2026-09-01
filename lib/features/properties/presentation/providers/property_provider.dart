import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';
import '../../data/datasources/property_datasource.dart';
import '../../data/repositories/property_repository_impl.dart';
import '../../domain/entities/property.dart';
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


// ============================================================
// PROPERTY BY ID
// ============================================================

final propertyByIdProvider =
FutureProvider.family<Property?, String>((ref, propertyId) async {
  final normalizedId = propertyId.trim();

  if (normalizedId.isEmpty) {
    return null;
  }

  final repository = ref.read(propertyRepositoryProvider);

  return repository.getPropertyById(normalizedId);
});