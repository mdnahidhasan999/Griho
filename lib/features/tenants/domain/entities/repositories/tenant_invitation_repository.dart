import '../tenant_invitation.dart';

abstract class TenantInvitationRepository {
  // ================================================================
  // CREATE INVITATION
  // ================================================================

  Future<TenantInvitation> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  });

  // ================================================================
  // GET INVITATION BY ID
  // ================================================================

  Future<TenantInvitation?> getInvitationById(
      String invitationId,
      );

  // ================================================================
  // GET INVITATION BY TOKEN
  // ================================================================

  Future<TenantInvitation?> getInvitationByToken(
      String token,
      );

  // ================================================================
  // GET PENDING INVITATION BY TENANT ID
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByTenantId(
      String tenantId,
      );

  // ================================================================
  // GET PENDING INVITATION BY PHONE
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByPhone(
      String phone,
      );

  // ================================================================
  // REALTIME — ALL TENANT INVITATIONS
  // ================================================================

  Stream<List<TenantInvitation>> watchInvitationsByTenantId(
      String tenantId,
      );

  // ================================================================
  // REALTIME — PENDING INVITATION
  // ================================================================

  Stream<TenantInvitation?> watchPendingInvitationByTenantId(
      String tenantId,
      );

  // ================================================================
  // ACCEPT INVITATION
  // ================================================================

  Future<void> acceptInvitation(
      String invitationId,
      );

  // ================================================================
  // CANCEL / REJECT INVITATION
  // ================================================================

  Future<void> cancelInvitation(
      String invitationId,
      );

  // ================================================================
  // EXPIRE INVITATION
  // ================================================================

  Future<void> expireInvitation(
      String invitationId,
      );
}