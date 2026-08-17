import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/invitation_repository.dart';
import '../../data/services/invitation_code_generator.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../../domain/usecases/create_invitation.dart';

final invitationRepositoryProvider =
Provider<InvitationRepository>((ref) {
  return InvitationRepositoryImpl();
});

final invitationCodeGeneratorProvider =
Provider<InvitationCodeGenerator>((ref) {
  return InvitationCodeGenerator();
});

final createInvitationProvider = Provider<CreateInvitation>((ref) {
  return CreateInvitation(
    repository: ref.watch(invitationRepositoryProvider),
  );
});