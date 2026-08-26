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

  Future<TenantInvitation?> getInvitationById(
      String invitationId,
      );

  // ============================================================
  // GET INVITATION BY TOKEN
  //
  // Used when tenant opens invitation link/code.
  // ============================================================

  Future<TenantInvitation?> getInvitationByToken(
      String token,
      );

  // ============================================================
  // GET PENDING INVITATION BY TENANT
  //
  // Used by owner to check invitation status.
  // ============================================================

  Future<TenantInvitation?>
  getPendingInvitationByTenantId(
      String tenantId,
      );

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> acceptInvitation(
      String invitationId,
      );

  // ============================================================
  // CANCEL INVITATION
  // ============================================================

  Future<void> cancelInvitation(
      String invitationId,
      );

  // ============================================================
  // EXPIRE INVITATION
  // ============================================================

  Future<void> expireInvitation(
      String invitationId,
      );
}