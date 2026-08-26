import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/repositories/tenant_invitation_repository.dart';
import '../../domain/entities/tenant_invitation.dart';

import '../datasources/tenant_invitation_data_source.dart';

class TenantInvitationRepositoryImpl implements TenantInvitationRepository {
  final TenantInvitationDataSource _dataSource;
  final CurrentUserService _currentUserService;

  const TenantInvitationRepositoryImpl({
    required this._dataSource,
    required this._currentUserService,
  });

  // ============================================================
  // CREATE INVITATION
  // CURRENT OWNER ONLY
  // ============================================================

  @override
  Future<TenantInvitation> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  }) {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.createInvitation(
      ownerId: ownerId,
      tenantId: tenantId,
      propertyId: propertyId,
      unitId: unitId,
      phone: phone,
    );
  }

  // ============================================================
  // GET INVITATION BY ID
  // ============================================================

  @override
  Future<TenantInvitation?> getInvitationById(String invitationId) {
    return _dataSource.getInvitationById(invitationId);
  }

  // ============================================================
  // GET INVITATION BY TOKEN
  //
  // Used by tenant during registration.
  // ============================================================

  @override
  Future<TenantInvitation?> getInvitationByToken(String token) {
    return _dataSource.getInvitationByToken(token);
  }

  // ============================================================
  // GET PENDING INVITATION BY TENANT
  // CURRENT OWNER ONLY
  // ============================================================

  @override
  Future<TenantInvitation?> getPendingInvitationByTenantId(String tenantId) {
    return _dataSource.getPendingInvitationByTenantId(tenantId);
  }

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  @override
  Future<void> acceptInvitation(String invitationId) {
    return _dataSource.acceptInvitation(invitationId);
  }

  // ============================================================
  // CANCEL INVITATION
  // ============================================================

  @override
  Future<void> cancelInvitation(String invitationId) {
    return _dataSource.cancelInvitation(invitationId);
  }

  // ============================================================
  // EXPIRE INVITATION
  // ============================================================

  @override
  Future<void> expireInvitation(String invitationId) {
    return _dataSource.expireInvitation(invitationId);
  }
}
