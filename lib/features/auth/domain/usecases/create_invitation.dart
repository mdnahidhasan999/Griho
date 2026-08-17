import '../entities/invitation.dart';
import '../entities/invitation_role.dart';
import '../repositories/invitation_repository.dart';

class CreateInvitation {
  final InvitationRepository _repository;

  CreateInvitation({
    required this._repository,
  });

  Future<void> call(Invitation invitation) {
    if (invitation.role == InvitationRole.manager ||
        invitation.role == InvitationRole.caretaker) {
      return _repository.createInvitation(invitation);
    }

    throw ArgumentError(
      'Only manager or caretaker invitations are allowed.',
    );
  }
}