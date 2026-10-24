import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class CreateTenantInvitation {
  final TenantInvitationRepository repository;

  const CreateTenantInvitation({
    required this.repository,
  });

  Future<TenantInvitation> call({
    String? tenantId,
    required String propertyId,
    required String unitId,
    String? phone,
    String? targetName,
    String? targetEmail,
    String? targetGrihoId,
    required double rentAmount,
  }) async {
    final normalizedTenantId = _normalize(tenantId);
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();

    final normalizedPhone = _normalize(phone);
    final normalizedName = _normalize(targetName);
    final normalizedEmail = _normalize(targetEmail)?.toLowerCase();
    final normalizedGrihoId = _normalize(targetGrihoId)?.toUpperCase();

    // --------------------------------------------------------------
    // PROPERTY AND UNIT VALIDATION
    // --------------------------------------------------------------

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    // --------------------------------------------------------------
    // RENT VALIDATION
    // --------------------------------------------------------------

    if (!rentAmount.isFinite || rentAmount <= 0) {
      throw ArgumentError(
        'Monthly rent must be a positive finite number.',
      );
    }

    // --------------------------------------------------------------
    // RECIPIENT VALIDATION
    //
    // Exactly one identifier is required:
    // Phone OR Email OR Griho ID.
    // UID is not an invitation input.
    // --------------------------------------------------------------

    final recipientIdentifiers = <String?>[
      normalizedPhone,
      normalizedEmail,
      normalizedGrihoId,
    ];

    final recipientCount =
        recipientIdentifiers
            .whereType<String>()
            .length;

    if (recipientCount != 1) {
      throw ArgumentError(
        'Provide exactly one recipient identifier: '
            'phone number, email address, or Griho ID.',
      );
    }

    // --------------------------------------------------------------
    // EMAIL VALIDATION
    // --------------------------------------------------------------

    if (normalizedEmail != null &&
        !_isValidEmail(normalizedEmail)) {
      throw ArgumentError(
        'Please provide a valid email address.',
      );
    }

    // --------------------------------------------------------------
    // PHONE VALIDATION
    // --------------------------------------------------------------

    if (normalizedPhone != null &&
        !_looksLikePhoneNumber(normalizedPhone)) {
      throw ArgumentError(
        'Please provide a valid phone number.',
      );
    }

    // --------------------------------------------------------------
    // GRIHO ID VALIDATION
    // --------------------------------------------------------------

    if (normalizedGrihoId != null &&
        !_isValidGrihoId(normalizedGrihoId)) {
      throw ArgumentError(
        'Please provide a valid Griho ID.',
      );
    }

    // --------------------------------------------------------------
    // OPTIONAL TENANT ID
    // --------------------------------------------------------------

    // tenantId is optional. When provided, the DataSource validates
    // that the existing tenant record belongs to this owner and
    // matches the selected property and unit.

    return repository.createInvitation(
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      unitId: normalizedUnitId,
      phone: normalizedPhone,
      targetName: normalizedName,
      targetEmail: normalizedEmail,
      targetGrihoId: normalizedGrihoId,
      rentAmount: rentAmount,
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String? _normalize(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  bool _looksLikePhoneNumber(String phone) {
    // Basic format check only. The DataSource performs the
    // application's phone normalization and validation.
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    return digits.length >= 7 && digits.length <= 15;
  }

  bool _isValidGrihoId(String grihoId) {
    // Accept a non-empty Griho ID with a reasonable length.
    // Actual ownership must be verified separately.
    return RegExp(
      r'^[A-Z0-9][A-Z0-9_-]{2,39}$',
    ).hasMatch(grihoId);
  }
}