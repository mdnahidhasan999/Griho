import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/repositories/tenant_invitation_repository.dart';
import '../../domain/entities/tenant_invitation.dart';

import '../datasources/tenant_invitation_data_source.dart';

class TenantInvitationRepositoryImpl
    implements TenantInvitationRepository {
  final TenantInvitationDataSource _dataSource;
  final CurrentUserService _currentUserService;

  const TenantInvitationRepositoryImpl({
    required this._dataSource,
    required this._currentUserService,
  });

  // ================================================================
  // CREATE INVITATION
  // CURRENT OWNER ONLY
  // ================================================================

  @override
  Future<TenantInvitation> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  }) {
    final ownerId =
        _currentUserService.requiredUid;

    return _dataSource.createInvitation(
      ownerId: ownerId,
      tenantId: tenantId,
      propertyId: propertyId,
      unitId: unitId,
      phone: phone,
      rentAmount: rentAmount,
    );
  }

  // ================================================================
  // GET INVITATION BY ID
  // ================================================================

  @override
  Future<TenantInvitation?> getInvitationById(
      String invitationId,
      ) {
    return _dataSource.getInvitationById(
      invitationId,
    );
  }

  // ================================================================
  // GET INVITATION BY TOKEN
  // ================================================================

  @override
  Future<TenantInvitation?> getInvitationByToken(
      String token,
      ) {
    return _dataSource.getInvitationByToken(
      token,
    );
  }

  // ================================================================
  // GET PENDING INVITATION BY TENANT ID
  // ================================================================

  @override
  Future<TenantInvitation?>
  getPendingInvitationByTenantId(
      String tenantId,
      ) {
    return _dataSource
        .getPendingInvitationByTenantId(
      tenantId,
    );
  }

  // ================================================================
  // GET PENDING INVITATION BY PHONE
  // ================================================================

  @override
  Future<TenantInvitation?>
  getPendingInvitationByPhone(
      String phone,
      ) {
    return _dataSource
        .getPendingInvitationByPhone(
      phone,
    );
  }

  // ================================================================
  // REALTIME — ALL INVITATIONS
  // ================================================================

  @override
  Stream<List<TenantInvitation>>
  watchInvitationsByTenantId(
      String tenantId,
      ) {
    return _dataSource
        .watchInvitationsByTenantId(
      tenantId,
    );
  }

  // ================================================================
  // REALTIME — PENDING INVITATION
  // ================================================================

  @override
  Stream<TenantInvitation?>
  watchPendingInvitationByTenantId(
      String tenantId,
      ) {
    return _dataSource
        .watchPendingInvitationByTenantId(
      tenantId,
    );
  }

  // ================================================================
  // ACCEPT INVITATION
  // ================================================================

  @override
  Future<void> acceptInvitation(
      String invitationId,
      ) {
    return _dataSource.acceptInvitation(
      invitationId,
    );
  }

  // ================================================================
  // CANCEL / REJECT INVITATION
  // ================================================================

  @override
  Future<void> cancelInvitation(
      String invitationId,
      ) {
    return _dataSource.cancelInvitation(
      invitationId,
    );
  }

  // ================================================================
  // EXPIRE INVITATION
  // ================================================================

  @override
  Future<void> expireInvitation(
      String invitationId,
      ) {
    return _dataSource.expireInvitation(
      invitationId,
    );
  }
}