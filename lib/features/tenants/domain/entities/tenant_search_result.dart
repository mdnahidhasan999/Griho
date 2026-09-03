class TenantSearchResult {
  /// Firebase Auth UID.
  /// Internal use only — never show this in UI.
  final String userId;

  /// Human-readable Griho ID.
  final String publicId;

  /// Registered Griho user's name.
  final String name;

  /// Registered Griho user's phone number.
  final String phone;

  /// Registered Griho user's email, if available.
  final String? email;

  /// Existing Tenant document ID, if this user is already a tenant.
  /// Internal use only — never show this in UI.
  final String? tenantId;

  /// Whether a Tenant document already exists for this Griho user.
  final bool isExistingTenant;

  const TenantSearchResult({
    required this.userId,
    required this.publicId,
    required this.name,
    required this.phone,
    this.email,
    this.tenantId,
    required this.isExistingTenant,
  });

  TenantSearchResult copyWith({
    String? userId,
    String? publicId,
    String? name,
    String? phone,
    String? email,
    String? tenantId,
    bool? isExistingTenant,
  }) {
    return TenantSearchResult(
      userId: userId ?? this.userId,
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      tenantId: tenantId ?? this.tenantId,
      isExistingTenant: isExistingTenant ?? this.isExistingTenant,
    );
  }
}
