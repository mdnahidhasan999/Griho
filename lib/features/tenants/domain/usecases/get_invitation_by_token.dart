import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class GetInvitationByToken {
  final TenantInvitationRepository _repository;

  const GetInvitationByToken({
    required this._repository,
  });

  Future<TenantInvitation?> call(
      String token,
      ) {
    return _repository.getInvitationByToken(
      token,
    );
  }
}