import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';

import '../../data/datasources/tenant_invitation_data_source.dart';
import '../../data/repositories/tenant_invitation_repository_impl.dart';

import '../../domain/entities/repositories/tenant_invitation_repository.dart';
import '../../domain/entities/tenant_invitation.dart';

import '../../domain/usecases/accept_tenant_invitation.dart';
import '../../domain/usecases/cancel_tenant_invitation.dart';
import '../../domain/usecases/create_tenant_invitation.dart';
import '../../domain/usecases/expire_tenant_invitation.dart';
import '../../domain/usecases/get_invitation_by_token.dart';
import '../../domain/usecases/get_pending_invitation_by_phone.dart';
import '../../domain/usecases/get_pending_tenant_invitation.dart';
import '../../domain/usecases/get_tenant_invitation.dart';
import '../../domain/usecases/link_and_accept_tenant_invitation.dart';

// ================================================================
// TENANT INVITATION DATA SOURCE
// ================================================================

final tenantInvitationDataSourceProvider =
Provider<TenantInvitationDataSource>((ref) {
  return TenantInvitationDataSource();
});

// ================================================================
// TENANT INVITATION REPOSITORY
// ================================================================

final tenantInvitationRepositoryProvider =
Provider<TenantInvitationRepository>((ref) {
  final dataSource = ref.watch(
    tenantInvitationDataSourceProvider,
  );

  return TenantInvitationRepositoryImpl(
    dataSource: dataSource,
    currentUserService: CurrentUserService(),
  );
});

// ================================================================
// CREATE TENANT INVITATION
// ================================================================

final createTenantInvitationProvider =
Provider<CreateTenantInvitation>((ref) {
  return CreateTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// GET TENANT INVITATION BY ID
// ================================================================

final getTenantInvitationProvider =
Provider<GetTenantInvitation>((ref) {
  return GetTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// GET INVITATION BY TOKEN
// ================================================================

final getInvitationByTokenProvider =
Provider<GetInvitationByToken>((ref) {
  return GetInvitationByToken(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// GET PENDING TENANT INVITATION BY TENANT ID
// ================================================================

final getPendingTenantInvitationProvider =
Provider<GetPendingTenantInvitation>((ref) {
  return GetPendingTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// GET PENDING INVITATION BY PHONE
// ================================================================

final getPendingInvitationByPhoneProvider =
Provider<GetPendingInvitationByPhone>((ref) {
  return GetPendingInvitationByPhone(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// ACCEPT TENANT INVITATION
// ================================================================

final acceptTenantInvitationProvider =
Provider<AcceptTenantInvitation>((ref) {
  return AcceptTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// CANCEL TENANT INVITATION
// ================================================================

final cancelTenantInvitationProvider =
Provider<CancelTenantInvitation>((ref) {
  return CancelTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// EXPIRE TENANT INVITATION
// ================================================================

final expireTenantInvitationProvider =
Provider<ExpireTenantInvitation>((ref) {
  return ExpireTenantInvitation(
    repository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// LINK AND ACCEPT TENANT INVITATION
// ================================================================

final linkAndAcceptTenantInvitationProvider =
Provider<LinkAndAcceptTenantInvitation>((ref) {
  return LinkAndAcceptTenantInvitation(
    invitationRepository: ref.watch(
      tenantInvitationRepositoryProvider,
    ),
  );
});

// ================================================================
// REALTIME — ALL INVITATIONS BY TENANT ID
// ================================================================

final tenantInvitationsProvider =
StreamProvider.family<List<TenantInvitation>, String>(
      (ref, tenantId) {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(
        const <TenantInvitation>[],
      );
    }

    final repository = ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository.watchInvitationsByTenantId(
      normalizedTenantId,
    );
  },
);

// ================================================================
// REALTIME — PENDING INVITATION BY TENANT ID
// ================================================================

final pendingTenantInvitationStreamProvider =
StreamProvider.family<TenantInvitation?, String>(
      (ref, tenantId) {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(null);
    }

    final repository = ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository.watchPendingInvitationByTenantId(
      normalizedTenantId,
    );
  },
);

// ================================================================
// REALTIME — INVITATIONS BY PHONE
// ================================================================

final tenantInvitationsByPhoneProvider =
StreamProvider.family<List<TenantInvitation>, String>(
      (ref, phone) {
    if (phone
        .trim()
        .isEmpty) {
      return Stream.value(
        const <TenantInvitation>[],
      );
    }

    final dataSource = ref.watch(
      tenantInvitationDataSourceProvider,
    );

    return dataSource.watchInvitationsByPhone(phone);
  },
);

// ================================================================
// GET PENDING INVITATION BY EMAIL
// ================================================================
//
// This provider finds a matching invitation.
// It does NOT establish that the signed-in user owns the email.
// Email verification must be checked before acceptance.
// ================================================================

final pendingTenantInvitationByEmailProvider =
FutureProvider.family<TenantInvitation?, String>(
      (ref, email) {
    if (email
        .trim()
        .isEmpty) {
      return Future.value(null);
    }

    final repository = ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository.getPendingInvitationByEmail(email);
  },
);

// ================================================================
// GET PENDING INVITATION BY GRIHO ID
// ================================================================
//
// This lookup is not proof of identity.
// The Griho ID must be verified against a trusted user profile.
// ================================================================

final pendingTenantInvitationByGrihoIdProvider =
FutureProvider.family<TenantInvitation?, String>(
      (ref, grihoId) {
    if (grihoId
        .trim()
        .isEmpty) {
      return Future.value(null);
    }

    final repository = ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository.getPendingInvitationByGrihoId(grihoId);
  },
);

// ================================================================
// CURRENT PENDING INVITATION FROM REALTIME HISTORY
// ================================================================

final currentPendingTenantInvitationProvider =
Provider.family<TenantInvitation?, String>(
      (ref, tenantId) {
    final invitations = ref.watch(
      tenantInvitationsProvider(tenantId),
    );

    return invitations.when(
      data: (items) {
        for (final invitation in items) {
          if (invitation.isPending) {
            return invitation;
          }
        }

        return null;
      },
      loading: () => null,
      error: (_, _) => null,
    );
  },
);