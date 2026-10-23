import '../entities/app_user.dart';

abstract class UserProfileRepository {
  Future<AppUser?> getUserByUid(String uid);

  Future<void> createUser(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<AppUser?> getUserByPublicId(String publicId);

  Future<AppUser?> getUserByPhone(String phoneNumber);

  Future<void> updateDefaultDashboard({
    required String uid,
    required String role,
  });

  Future<void> saveOwnerRole(String uid);

  Future<void> saveInitialRole(String uid, String role);
}
