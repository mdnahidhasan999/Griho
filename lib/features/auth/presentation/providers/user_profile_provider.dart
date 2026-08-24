import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/usecases/get_user_by_phone.dart';
import 'auth_provider.dart';

final getUserByPhoneProvider = Provider<GetUserByPhone>((ref) {
  return GetUserByPhone(
    repository: ref.read(userProfileRepositoryProvider),
  );
});

final userByPhoneProvider =
FutureProvider.family<AppUser?, String>((ref, phoneNumber) async {
  final getUserByPhone = ref.read(getUserByPhoneProvider);

  return getUserByPhone(phoneNumber);
});