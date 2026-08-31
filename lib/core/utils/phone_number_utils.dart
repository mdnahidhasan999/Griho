class PhoneNumberUtils {
  PhoneNumberUtils._();

  /// Griho stores every phone number in E.164 format.
  ///
  /// Examples:
  /// +8801971959442
  /// +14155552671
  /// +447911123456
  static String normalize(String phone) {
    final value = phone.trim();

    if (value.isEmpty) {
      throw const FormatException('Phone number cannot be empty.');
    }

    if (!value.startsWith('+')) {
      throw const FormatException(
        'Phone number must be in international E.164 format.',
      );
    }

    return value;
  }

  /// Basic E.164 format validation.
  ///
  /// E.164:
  /// + followed by 7-15 digits.
  static bool isValid(String phone) {
    final value = phone.trim();

    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(value);
  }

  /// Normalizes and validates a phone number in one operation.
  static String normalizeAndValidate(String phone) {
    final normalized = normalize(phone);

    if (!isValid(normalized)) {
      throw const FormatException(
        'Phone number must be a valid E.164 phone number.',
      );
    }

    return normalized;
  }
}
