import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/property.dart';
import 'property_provider.dart';
import 'property_usecase_provider.dart';

final currentOwnerPropertiesProvider = FutureProvider<List<Property>>((
  ref,
) async {
  final currentUserService = ref.read(currentUserServiceProvider);

  final getProperties = ref.read(getPropertiesProvider);

  final ownerId = currentUserService.requiredUid;

  return getProperties(ownerId);
});
