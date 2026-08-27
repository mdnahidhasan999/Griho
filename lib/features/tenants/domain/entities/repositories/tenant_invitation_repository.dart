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
  // Used when tenant opens an invitation link/code.
  // ============================================================

  Future<TenantInvitation?> getInvitationByToken(
      String token,
      );

  // ============================================================
  // GET PENDING INVITATION BY TENANT
  //
  // Used by owner.
  // ============================================================

  Future<TenantInvitation?> getPendingInvitationByTenantId(
      String tenantId,
      );

  // ============================================================
  // GET PENDING INVITATION BY PHONE
  //
  // Used during tenant account linking.
  //
  // Firebase Auth phone number is matched against the
  // invitation phone number.
  // ============================================================

  Future<TenantInvitation?> getPendingInvitationByPhone(
      String phone,
      );

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> acceptInvitation(
      String invitationId,
      );

  // ============================================================
  // CANCEL INVITATION
  //
  // Both owner and tenant can cancel.
  // Authorization must be enforced in the data layer / rules.
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