enum UserRole {
  owner,
  manager,
  caretaker,
  tenant,
}

class AppUser {
  final String uid;
  final String publicId;
  final UserRole role;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.publicId,
    required this.role,
    required this.name,
    this.phoneNumber,
    this.email,
    this.photoUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}