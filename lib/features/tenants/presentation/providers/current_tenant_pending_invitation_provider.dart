import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant_invitation.dart';
import 'tenant_dashboard_provider.dart';
import 'tenant_invitation_provider.dart';

/// Realtime pending invitation for the currently signed-in tenant.
///
/// Invitation lookup is based on tenantId, not phone number.
///
/// This provider is kept for compatibility with existing code that
/// still references currentTenantPendingInvitationProvider.
final currentTenantPendingInvitationProvider =
StreamProvider.autoDispose<TenantInvitation?>((ref) async* {
  final tenant = await ref.watch(
    currentTenantProvider.future,
  );

  if (tenant == null) {
    yield null;
    return;
  }

  final tenantId = tenant.id.trim();

  if (tenantId.isEmpty) {
    yield null;
    return;
  }

  final repository = ref.read(
    tenantInvitationRepositoryProvider,
  );

  yield* repository.watchPendingInvitationByTenantId(
    tenantId,
  );
});