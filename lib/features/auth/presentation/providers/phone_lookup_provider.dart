import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/phone_lookup_data_source.dart';
import '../../data/repositories/phone_lookup_repository_impl.dart';
import '../../domain/repositories/phone_lookup_repository.dart';
import '../../domain/usecases/get_user_uid_by_phone.dart';

final phoneLookupDataSourceProvider = Provider<PhoneLookupDataSource>((ref) {
  return PhoneLookupDataSource();
});

final phoneLookupRepositoryProvider = Provider<PhoneLookupRepository>((ref) {
  return PhoneLookupRepositoryImpl(
    dataSource: ref.read(phoneLookupDataSourceProvider),
  );
});

final getUserByPhoneLookupProvider = Provider<GetUserByPhoneLookup>((ref) {
  return GetUserByPhoneLookup(
    repository: ref.read(phoneLookupRepositoryProvider),
  );
});
