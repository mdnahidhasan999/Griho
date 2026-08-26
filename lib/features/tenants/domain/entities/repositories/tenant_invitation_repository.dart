import '../tenant_invitation.dart';

abstract class TenantInvitationRepository {
  // ============================================================
  // CREATE INVITATION
  // ============================================================

  Future<TenantInvitation> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  });

  // ============================================================
  // GET INVITATION BY ID
  // ============================================================

  Future<TenantInvitation?> getInvitationById(String invitationId,);

  // ============================================================
  // GET INVITATION BY TOKEN
  //
  // Used by tenant registration.
  // ============================================================

  Future<TenantInvitation?> getInvitationByToken(String token,);

  // ============================================================
  // GET PENDING INVITATION BY TENANT
  //
  // Used by owner.
  // ============================================================

  Future<TenantInvitation?> getPendingInvitationByTenantId(String tenantId,);

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> acceptInvitation(String invitationId,);

  // ============================================================
  // CANCEL INVITATION
  //
  // Both owner and tenant can cancel,
  // but authorization will be enforced separately.
  // ============================================================

  Future<void> cancelInvitation(String invitationId,);

  // ============================================================
  // EXPIRE INVITATION
  // ============================================================

  Future<void> expireInvitation(String invitationId,);
}