// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import 'auth_provider.dart';

export 'auth_provider.dart' show userProfileDataSourceProvider;

final userByPhoneProvider = FutureProvider.family<AppUser?, String>((
  ref,
  phone,
) async {
  final normalizedPhone = phone.trim();
  if (normalizedPhone.isEmpty) {
    return null;
  }

  final dataSource = ref.read(userProfileDataSourceProvider);
  return dataSource.getUserByPhone(normalizedPhone);
});
