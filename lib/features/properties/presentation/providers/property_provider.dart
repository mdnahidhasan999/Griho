// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';
import '../../data/datasources/property_datasource.dart';
import '../../data/repositories/property_repository_impl.dart';
import '../../domain/entities/property.dart';
import '../../domain/repositories/property_repository.dart';
import 'current_owner_properties_provider.dart';

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

/// Cache-first lookup: reuses `currentOwnerPropertiesProvider` if already loaded.
final propertyByIdProvider = FutureProvider.family<Property?, String>((
  ref,
  propertyId,
) async {
  final normalizedId = propertyId.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  final cachedList = ref.read(currentOwnerPropertiesProvider).value;
  if (cachedList != null) {
    for (final property in cachedList) {
      if (property.id == normalizedId) {
        return property;
      }
    }
  }

  final repository = ref.read(propertyRepositoryProvider);
  return repository.getPropertyById(normalizedId);
});
