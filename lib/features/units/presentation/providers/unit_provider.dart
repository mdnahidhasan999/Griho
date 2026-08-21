import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/unit_datasource.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../domain/repositories/unit_repository_impl.dart';

final unitDataSourceProvider = Provider<UnitDataSource>((ref) {
  return UnitDataSource();
});

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  final dataSource = ref.read(unitDataSourceProvider);

  return UnitRepositoryImpl(dataSource: dataSource);
});
