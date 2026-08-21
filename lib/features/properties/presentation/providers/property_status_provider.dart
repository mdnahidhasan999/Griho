import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:griho/features/properties/presentation/providers/property_provider.dart';

import '../../domain/usecases/update_property_status.dart';

final updatePropertyStatusProvider = Provider<UpdatePropertyStatus>((ref) {
  final repository = ref.read(propertyRepositoryProvider);

  return UpdatePropertyStatus(repository);
});
