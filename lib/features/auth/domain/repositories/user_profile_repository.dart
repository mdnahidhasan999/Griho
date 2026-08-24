import '../entities/app_user.dart';

abstract class UserProfileRepository {
  Future<AppUser?> getUserByUid(String uid);

  Future<void> createUser(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<AppUser?> getUserByPublicId(String publicId);

  Future<AppUser?> getUserByPhone(String phoneNumber);
}