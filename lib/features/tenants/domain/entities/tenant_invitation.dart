import 'package:flutter/foundation.dart';

enum TenantInvitationStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  expired,
}

@immutable
class TenantInvitation {
  const TenantInvitation({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.rentAmount,
    required this.status,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    this.tenantId,
    this.phone,
    this.targetName,
    this.targetEmail,
    this.targetGrihoId,
    this.propertyName,
    this.propertyCode,
    this.unitNumber,
    this.unitName,
    this.acceptedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.updatedAt,
  });

  /// Invitation document ID.
  final String id;

  /// ID of the owner who created the invitation.
  final String ownerId;

  /// Existing tenant document ID, if available.
  ///
  /// This remains null when an invitation is created
  /// before a tenant document exists.
  final String? tenantId;

  /// Property associated with the invitation.
  final String propertyId;

  /// Unit associated with the invitation.
  final String unitId;

  /// Recipient phone number.
  final String? phone;

  /// Recipient display name.
  final String? targetName;

  /// Recipient email address.
  final String? targetEmail;

  /// Recipient Griho ID.
  final String? targetGrihoId;

  /// Property name stored for invitation display.
  final String? propertyName;

  /// Property code stored for invitation display.
  final String? propertyCode;

  /// Unit number stored for invitation display.
  final String? unitNumber;

  /// Unit name stored for invitation display.
  final String? unitName;

  /// Proposed rent amount.
  final double rentAmount;

  /// Current invitation status.
  final TenantInvitationStatus status;

  /// Invitation token.
  final String token;

  /// Invitation creation timestamp.
  final DateTime createdAt;

  /// Invitation expiration timestamp.
  final DateTime expiresAt;

  /// Invitation acceptance timestamp.
  final DateTime? acceptedAt;

  /// Invitation rejection timestamp.
  final DateTime? rejectedAt;

  /// Invitation cancellation timestamp.
  final DateTime? cancelledAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Whether the invitation has expired.
  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  /// Whether the invitation is pending and has not expired.
  bool get isPending =>
      status == TenantInvitationStatus.pending && !isExpired;

  /// Returns the first available recipient identifier.
  ///
  /// This is for display purposes only.
  /// It does not verify ownership of the identifier.
  String? get recipientIdentifier {
    final email = _normalize(targetEmail);
    if (email != null) return email;

    final phoneNumber = _normalize(phone);
    if (phoneNumber != null) return phoneNumber;

    final grihoId = _normalize(targetGrihoId);
    if (grihoId != null) return grihoId;

    return null;
  }

  /// Creates a copy while preserving values that are not changed.
  ///
  /// Nullable fields can explicitly be set to null.
  TenantInvitation copyWith({
    String? id,
    String? ownerId,
    Object? tenantId = _unset,
    String? propertyId,
    String? unitId,
    Object? phone = _unset,
    Object? targetName = _unset,
    Object? targetEmail = _unset,
    Object? targetGrihoId = _unset,
    Object? propertyName = _unset,
    Object? propertyCode = _unset,
    Object? unitNumber = _unset,
    Object? unitName = _unset,
    double? rentAmount,
    TenantInvitationStatus? status,
    String? token,
    DateTime? createdAt,
    DateTime? expiresAt,
    Object? acceptedAt = _unset,
    Object? rejectedAt = _unset,
    Object? cancelledAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return TenantInvitation(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      tenantId: identical(tenantId, _unset)
          ? this.tenantId
          : tenantId as String?,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      targetName: identical(targetName, _unset)
          ? this.targetName
          : targetName as String?,
      targetEmail: identical(targetEmail, _unset)
          ? this.targetEmail
          : targetEmail as String?,
      targetGrihoId: identical(targetGrihoId, _unset)
          ? this.targetGrihoId
          : targetGrihoId as String?,
      propertyName: identical(propertyName, _unset)
          ? this.propertyName
          : propertyName as String?,
      propertyCode: identical(propertyCode, _unset)
          ? this.propertyCode
          : propertyCode as String?,
      unitNumber: identical(unitNumber, _unset)
          ? this.unitNumber
          : unitNumber as String?,
      unitName: identical(unitName, _unset)
          ? this.unitName
          : unitName as String?,
      rentAmount: rentAmount ?? this.rentAmount,
      status: status ?? this.status,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: identical(acceptedAt, _unset)
          ? this.acceptedAt
          : acceptedAt as DateTime?,
      rejectedAt: identical(rejectedAt, _unset)
          ? this.rejectedAt
          : rejectedAt as DateTime?,
      cancelledAt: identical(cancelledAt, _unset)
          ? this.cancelledAt
          : cancelledAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  static const Object _unset = Object();

  static String? _normalize(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}