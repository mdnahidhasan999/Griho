import '../entities/invitation.dart';

abstract class InvitationRepository {
  Future<void> createInvitation(
      Invitation invitation,
      );

  Future<Invitation?> getInvitationById(
      String invitationId,
      );

  Future<Invitation?> getPendingInvitationByCode(
      String invitationCode,
      );

  Future<List<Invitation>> getPendingInvitationsForUser({
    required String userId,
    required String phoneNumber,
  });

  Future<void> updateInvitation(
      Invitation invitation,
      );
}