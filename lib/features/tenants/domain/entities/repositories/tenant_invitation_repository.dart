import '../tenant_invitation.dart';

abstract class TenantInvitationRepository {
  // ================================================================
  // CREATE INVITATION
  // ================================================================

  Future<TenantInvitation> createInvitation({
    String? tenantId,
    required String propertyId,
    required String unitId,
    String? phone,
    String? targetName,
    String? targetEmail,
    String? targetGrihoId,
    required double rentAmount,
  });

  // ================================================================
  // GET INVITATION BY ID
  // ================================================================

  Future<TenantInvitation?> getInvitationById(String invitationId,);

  // ================================================================
  // GET INVITATION BY TOKEN
  // ================================================================

  Future<TenantInvitation?> getInvitationByToken(String token,);

  // ================================================================
  // GET PENDING INVITATION BY TENANT ID
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByTenantId(String tenantId,);

  // ================================================================
  // GET PENDING INVITATION BY PHONE
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByPhone(String phone,);

  // ================================================================
  // GET PENDING INVITATION BY EMAIL
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByEmail(String email,);

  // ================================================================
  // GET PENDING INVITATION BY GRIHO ID
  // ================================================================

  Future<TenantInvitation?> getPendingInvitationByGrihoId(String grihoId,);

  // ================================================================
  // REALTIME — ALL TENANT INVITATIONS
  // ================================================================

  Stream<List<TenantInvitation>> watchInvitationsByTenantId(String tenantId,);

  // ================================================================
  // REALTIME — PENDING INVITATION
  // ================================================================

  Stream<TenantInvitation?> watchPendingInvitationByTenantId(String tenantId,);

  // ================================================================
  // REALTIME — INVITATIONS BY PHONE
  // ================================================================

  Stream<List<TenantInvitation>> watchInvitationsByPhone(String phone,);

  // ================================================================
  // ACCEPT INVITATION
  // ================================================================

  Future<void> acceptInvitation(String invitationId,);

  // ================================================================
  // CANCEL / REJECT INVITATION
  // ================================================================

  Future<void> cancelInvitation(String invitationId,);

  // ================================================================
  // EXPIRE INVITATION
  // ================================================================

  Future<void> expireInvitation(String invitationId,);
}