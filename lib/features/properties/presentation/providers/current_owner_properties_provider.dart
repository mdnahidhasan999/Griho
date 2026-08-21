import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/property.dart';
import '../providers/property_provider.dart';
import '../providers/property_usecase_provider.dart';

final currentOwnerPropertiesProvider =
FutureProvider<List<Property>>((ref) async {
  final currentUserService = ref.read(
    currentUserServiceProvider,
  );

  final ownerId = currentUserService.requiredUid;

  final getProperties = ref.read(
    getPropertiesProvider,
  );

  return getProperties(ownerId);
});