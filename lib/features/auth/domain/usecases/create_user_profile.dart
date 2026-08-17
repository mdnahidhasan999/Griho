// ignore_for_file: prefer_initializing_formals

import '../entities/app_user.dart';
import '../repositories/user_profile_repository.dart';

class CreateUserProfile {
  final UserProfileRepository _repository;

  CreateUserProfile({
    required UserProfileRepository repository,
  }) : _repository = repository;

  Future<void> call(AppUser user) {
    return _repository.createUser(user);
  }
}