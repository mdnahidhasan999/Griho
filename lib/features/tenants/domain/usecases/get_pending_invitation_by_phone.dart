import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class GetPendingInvitationByPhone {
  final TenantInvitationRepository _repository;

  const GetPendingInvitationByPhone({
    required this._repository,
  });

  Future<TenantInvitation?> call(
      String phone,
      ) {
    return _repository.getPendingInvitationByPhone(
      phone,
    );
  }
}