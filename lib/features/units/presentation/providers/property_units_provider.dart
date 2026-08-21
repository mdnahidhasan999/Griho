import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/unit.dart';
import 'unit_usecase_provider.dart';

final propertyUnitsProvider = FutureProvider.family<
    List<Unit>,
    String>((ref, propertyId) async {
  final normalizedPropertyId = propertyId.trim();

  if (normalizedPropertyId.isEmpty) {
    throw ArgumentError(
      'Property ID cannot be empty.',
    );
  }

  final getUnitsByPropertyId = ref.read(
    getUnitsByPropertyIdProvider,
  );

  return getUnitsByPropertyId(
    normalizedPropertyId,
  );
});