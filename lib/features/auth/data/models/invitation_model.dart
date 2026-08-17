import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/invitation.dart';
import '../../domain/entities/invitation_role.dart';
import '../../domain/entities/invitation_status.dart';

class InvitationModel extends Invitation {
  const InvitationModel({
    required super.id,
    required super.propertyId,
    required super.invitedByUserId,
    super.targetUserId,
    super.targetPhoneNumber,
    required super.role,
    required super.invitationCode,
    required super.status,
    required super.createdAt,
    required super.expiresAt,
    super.respondedAt,
  });

  factory InvitationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Invitation document does not exist.');
    }

    return InvitationModel(
      id: document.id,
      propertyId: data['propertyId'] as String,
      invitedByUserId: data['invitedByUserId'] as String,
      targetUserId: data['targetUserId'] as String?,
      targetPhoneNumber: data['targetPhoneNumber'] as String?,
      role: _roleFromString(data['role'] as String),
      invitationCode: data['invitationCode'] as String,
      status: _statusFromString(data['status'] as String),
      createdAt: _dateTimeFromTimestamp(data['createdAt']),
      expiresAt: _dateTimeFromTimestamp(data['expiresAt']),
      respondedAt: _optionalDateTimeFromTimestamp(
        data['respondedAt'],
      ),
    );
  }

  factory InvitationModel.fromEntity(Invitation invitation) {
    return InvitationModel(
      id: invitation.id,
      propertyId: invitation.propertyId,
      invitedByUserId: invitation.invitedByUserId,
      targetUserId: invitation.targetUserId,
      targetPhoneNumber: invitation.targetPhoneNumber,
      role: invitation.role,
      invitationCode: invitation.invitationCode,
      status: invitation.status,
      createdAt: invitation.createdAt,
      expiresAt: invitation.expiresAt,
      respondedAt: invitation.respondedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'propertyId': propertyId,
      'invitedByUserId': invitedByUserId,
      'targetUserId': targetUserId,
      'targetPhoneNumber': targetPhoneNumber,
      'role': role.name,
      'invitationCode': invitationCode,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'respondedAt': respondedAt == null
          ? null
          : Timestamp.fromDate(respondedAt!),
    };
  }

  static InvitationRole _roleFromString(String value) {
    return InvitationRole.values.firstWhere(
          (role) => role.name == value,
      orElse: () => throw StateError(
        'Invalid invitation role: $value',
      ),
    );
  }

  static InvitationStatus _statusFromString(String value) {
    return InvitationStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () => throw StateError(
        'Invalid invitation status: $value',
      ),
    );
  }

  static DateTime _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError('Invalid timestamp value.');
  }

  static DateTime? _optionalDateTimeFromTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError('Invalid optional timestamp value.');
  }
}