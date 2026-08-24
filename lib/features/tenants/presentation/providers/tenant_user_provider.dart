import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/user_profile_provider.dart';

final tenantUserByPhoneProvider =
FutureProvider.family<AppUser?, String>((ref, phoneNumber) async {
  final normalizedPhone = phoneNumber.trim();

  if (normalizedPhone.isEmpty) {
    return null;
  }

  return ref.read(userByPhoneProvider(normalizedPhone).future);
});