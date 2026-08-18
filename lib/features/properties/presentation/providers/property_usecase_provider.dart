import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/create_property.dart';
import '../../domain/usecases/delete_property.dart';
import '../../domain/usecases/get_properties.dart';
import '../../domain/usecases/get_property.dart';
import '../../domain/usecases/update_property.dart';
import 'property_provider.dart';

final createPropertyProvider = Provider<CreateProperty>((ref) {
  return CreateProperty(
    repository: ref.watch(propertyRepositoryProvider),
  );
});

final getPropertiesProvider = Provider<GetProperties>((ref) {
  return GetProperties(
    repository: ref.watch(propertyRepositoryProvider),
  );
});

final getPropertyProvider = Provider<GetProperty>((ref) {
  return GetProperty(
    repository: ref.watch(propertyRepositoryProvider),
  );
});

final updatePropertyProvider = Provider<UpdateProperty>((ref) {
  return UpdateProperty(
    repository: ref.watch(propertyRepositoryProvider),
  );
});

final deletePropertyProvider = Provider<DeleteProperty>((ref) {
  return DeleteProperty(
    repository: ref.watch(propertyRepositoryProvider),
  );
});