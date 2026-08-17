import 'invitation_role.dart';
import 'invitation_status.dart';

class Invitation {
  final String id;
  final String propertyId;
  final String invitedByUserId;
  final String? targetUserId;
  final String? targetPhoneNumber;
  final InvitationRole role;
  final String invitationCode;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  const Invitation({
    required this.id,
    required this.propertyId,
    required this.invitedByUserId,
    this.targetUserId,
    this.targetPhoneNumber,
    required this.role,
    required this.invitationCode,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });
}