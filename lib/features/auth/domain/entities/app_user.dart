class AppUser {
  final String uid;
  final String publicId;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? photoUrl;
  final String? defaultDashboard;
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
    this.defaultDashboard,
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
    String? defaultDashboard,
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
      defaultDashboard: defaultDashboard ?? this.defaultDashboard,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
