import '../tenant_invitation.dart';

abstract class TenantInvitationRepository {
  Future<TenantInvitation> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  });

  Future<TenantInvitation?> getInvitationById(String invitationId);

  Future<TenantInvitation?> getInvitationByToken(String token);

  Future<TenantInvitation?> getPendingInvitationByTenantId(String tenantId);

  Future<TenantInvitation?> getPendingInvitationByPhone(String phone);

  Future<void> acceptInvitation(String invitationId);

  Future<void> cancelInvitation(String invitationId);

  Future<void> expireInvitation(String invitationId);
}
