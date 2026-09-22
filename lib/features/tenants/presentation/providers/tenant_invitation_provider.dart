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
Provider<TenantInvitationDataSource>(
      (ref) {
    return TenantInvitationDataSource();
  },
);

// ================================================================
// TENANT INVITATION REPOSITORY
// ================================================================

final tenantInvitationRepositoryProvider =
Provider<TenantInvitationRepository>(
      (ref) {
    final dataSource =
    ref.read(
      tenantInvitationDataSourceProvider,
    );

    final currentUserService =
    CurrentUserService();

    return TenantInvitationRepositoryImpl(
      dataSource: dataSource,
      currentUserService: currentUserService,
    );
  },
);

// ================================================================
// CREATE TENANT INVITATION
// ================================================================

final createTenantInvitationProvider =
Provider<CreateTenantInvitation>(
      (ref) {
    return CreateTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// GET TENANT INVITATION
// ================================================================

final getTenantInvitationProvider =
Provider<GetTenantInvitation>(
      (ref) {
    return GetTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// GET INVITATION BY TOKEN
// ================================================================

final getInvitationByTokenProvider =
Provider<GetInvitationByToken>(
      (ref) {
    return GetInvitationByToken(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// GET PENDING TENANT INVITATION
// BY TENANT ID
// ================================================================

final getPendingTenantInvitationProvider =
Provider<GetPendingTenantInvitation>(
      (ref) {
    return GetPendingTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// GET PENDING INVITATION BY PHONE
// ================================================================

final getPendingInvitationByPhoneProvider =
Provider<GetPendingInvitationByPhone>(
      (ref) {
    return GetPendingInvitationByPhone(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// ACCEPT TENANT INVITATION
// ================================================================

final acceptTenantInvitationProvider =
Provider<AcceptTenantInvitation>(
      (ref) {
    return AcceptTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// CANCEL TENANT INVITATION
// ================================================================

final cancelTenantInvitationProvider =
Provider<CancelTenantInvitation>(
      (ref) {
    return CancelTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// EXPIRE TENANT INVITATION
// ================================================================

final expireTenantInvitationProvider =
Provider<ExpireTenantInvitation>(
      (ref) {
    return ExpireTenantInvitation(
      repository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// LINK AND ACCEPT TENANT INVITATION
// ================================================================

final linkAndAcceptTenantInvitationProvider =
Provider<LinkAndAcceptTenantInvitation>(
      (ref) {
    return LinkAndAcceptTenantInvitation(
      invitationRepository: ref.read(
        tenantInvitationRepositoryProvider,
      ),
    );
  },
);

// ================================================================
// REALTIME — ALL TENANT INVITATIONS
// ================================================================
//
// This is the main realtime source for the tenant's invitation
// history.
//
// Firestore snapshots() emits:
//
// 1. Initial data
// 2. New invitation
// 3. Accepted invitation
// 4. Cancelled invitation
// 5. Rejected invitation
// 6. Expired invitation
//
// No hot reload is required.
//

final tenantInvitationsProvider =
StreamProvider.family<
    List<TenantInvitation>,
    String>(
      (ref, tenantId) {
    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(
        const <TenantInvitation>[],
      );
    }

    final repository =
    ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository
        .watchInvitationsByTenantId(
      normalizedTenantId,
    );
  },
);

// ================================================================
// REALTIME — PENDING INVITATION
// ================================================================
//
// This replaces the old one-time Future-based pending invitation
// flow for screens that need live updates.
//

final pendingTenantInvitationStreamProvider =
StreamProvider.family<
    TenantInvitation?,
    String>(
      (ref, tenantId) {
    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(null);
    }

    final repository =
    ref.watch(
      tenantInvitationRepositoryProvider,
    );

    return repository
        .watchPendingInvitationByTenantId(
      normalizedTenantId,
    );
  },
);

// ================================================================
// PENDING INVITATION FROM REALTIME HISTORY
// ================================================================
//
// Useful when the UI already watches the complete invitation
// history and wants the latest pending invitation.
//

final currentPendingTenantInvitationProvider =
Provider.family<
    TenantInvitation?,
    String>(
      (ref, tenantId) {
    final invitations =
    ref.watch(
      tenantInvitationsProvider(
        tenantId,
      ),
    );

    return invitations.when(
      data: (items) {
        for (final invitation in items) {
          if (invitation.isValid) {
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