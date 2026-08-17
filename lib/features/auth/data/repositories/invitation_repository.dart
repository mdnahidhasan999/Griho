import '../../domain/entities/invitation.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../datasources/invitation_datasource.dart';
import '../models/invitation_model.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final InvitationDataSource _dataSource;

  InvitationRepositoryImpl({
    InvitationDataSource? dataSource,
  }) : _dataSource = dataSource ?? InvitationDataSource();

  @override
  Future<void> createInvitation(
      Invitation invitation,
      ) {
    return _dataSource.createInvitation(
      InvitationModel.fromEntity(invitation),
    );
  }

  @override
  Future<Invitation?> getInvitationById(
      String invitationId,
      ) {
    return _dataSource.getInvitationById(
      invitationId,
    );
  }

  @override
  Future<Invitation?> getPendingInvitationByCode(
      String invitationCode,
      ) {
    return _dataSource.getPendingInvitationByCode(
      invitationCode,
    );
  }

  @override
  Future<List<Invitation>> getPendingInvitationsForUser({
    required String userId,
    required String phoneNumber,
  }) {
    return _dataSource.getPendingInvitationsForUser(
      userId: userId,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<void> updateInvitation(
      Invitation invitation,
      ) {
    return _dataSource.updateInvitation(
      InvitationModel.fromEntity(invitation),
    );
  }
}