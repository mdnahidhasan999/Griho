import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/user_profile_datasource.dart';

import '../../domain/entities/app_user.dart';

final userProfileDataSourceProvider = Provider<UserProfileDataSource>((ref) {
  return UserProfileDataSource();
});

final userByPhoneProvider = FutureProvider.family<AppUser?, String>((
  ref,
  phone,
) async {
  final dataSource = ref.read(userProfileDataSourceProvider);

  final user = await dataSource.getUserByPhone(phone);

  return user;
});
