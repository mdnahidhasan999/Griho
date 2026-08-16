import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileDataSource _dataSource;

  UserProfileRepositoryImpl({UserProfileDataSource? dataSource})
    : _dataSource = dataSource ?? UserProfileDataSource();

  @override
  Future<AppUser?> getUserByUid(String uid) {
    return _dataSource.getUserByUid(uid);
  }

  @override
  Future<void> createUser(AppUser user) {
    final model = AppUserModel.fromEntity(user);

    return _dataSource.createUser(model);
  }

  @override
  Future<void> updateUser(AppUser user) {
    final model = AppUserModel.fromEntity(user);

    return _dataSource.updateUser(model);
  }

  @override
  Future<AppUser?> getUserByPublicId(String publicId) {
    return _dataSource.getUserByPublicId(publicId);
  }
}
