import '../entities/app_user.dart';
import '../repositories/user_profile_repository.dart';

class GetUserByPhone {
  final UserProfileRepository _repository;

  const GetUserByPhone({
    required this._repository,
  });

  Future<AppUser?> call(String phoneNumber) {
    return _repository.getUserByPhone(
      phoneNumber.trim(),
    );
  }
}