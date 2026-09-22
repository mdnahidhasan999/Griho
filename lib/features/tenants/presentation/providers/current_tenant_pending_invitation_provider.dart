import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../domain/entities/tenant_invitation.dart';
import 'tenant_invitation_provider.dart';

/// Loads the currently signed-in tenant's pending invitation.
///
/// This provider is intentionally independent from:
/// - tenantAccess
/// - active tenancy
/// - unit access
///
/// A tenant must be able to see a pending invitation BEFORE
/// accepting it. Therefore this provider only uses the authenticated
/// Firebase phone number and the invitation repository.
final currentTenantPendingInvitationProvider =
FutureProvider.autoDispose<TenantInvitation?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return null;
  }

  final firebasePhone = user.phoneNumber?.trim();

  if (firebasePhone == null || firebasePhone.isEmpty) {
    return null;
  }

  final normalizedPhone =
  PhoneNumberUtils.normalizeAndValidate(firebasePhone);

  final repository = ref.read(
    tenantInvitationRepositoryProvider,
  );

  return repository.getPendingInvitationByPhone(
    normalizedPhone,
  );
});