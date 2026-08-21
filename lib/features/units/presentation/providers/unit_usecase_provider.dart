import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/create_unit.dart';
import '../../domain/usecases/delete_unit.dart';
import '../../domain/usecases/get_unit.dart';
import '../../domain/usecases/get_units_by_property_id.dart';
import '../../domain/usecases/update_unit.dart';
import 'unit_provider.dart';

final createUnitProvider = Provider<CreateUnit>((ref) {
  final repository = ref.read(unitRepositoryProvider);

  return CreateUnit(repository);
});

final getUnitProvider = Provider<GetUnit>((ref) {
  final repository = ref.read(unitRepositoryProvider);

  return GetUnit(repository);
});

final getUnitsByPropertyIdProvider =
Provider<GetUnitsByPropertyId>((ref) {
  final repository = ref.read(unitRepositoryProvider);

  return GetUnitsByPropertyId(repository);
});

final updateUnitProvider = Provider<UpdateUnit>((ref) {
  final repository = ref.read(unitRepositoryProvider);

  return UpdateUnit(repository);
});

final deleteUnitProvider = Provider<DeleteUnit>((ref) {
  final repository = ref.read(unitRepositoryProvider);

  return DeleteUnit(repository);
});