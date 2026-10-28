class AppUser {
  final String uid;
  final String publicId;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? photoUrl;
  final String? nidNumber;

  // The dashboard selected to open by default.
  final String? defaultDashboard;

  // Roles that have been authorized for this user.
  final List<String> availableRoles;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.publicId,
    required this.name,
    this.phoneNumber,
    this.email,
    this.photoUrl,
    this.nidNumber,
    this.defaultDashboard,
    this.availableRoles = const [],
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    String? uid,
    String? publicId,
    String? name,
    String? phoneNumber,
    String? email,
    String? photoUrl,
    String? nidNumber,
    String? defaultDashboard,
    List<String>? availableRoles,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      nidNumber: nidNumber ?? this.nidNumber,
      defaultDashboard: defaultDashboard ?? this.defaultDashboard,
      availableRoles: availableRoles ?? this.availableRoles,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
