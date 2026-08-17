import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:griho/features/auth/domain/repositories/firebase_auth_repository.dart';

import '../../data/datasources/user_profile_datasource.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final userProfileDataSourceProvider = Provider<UserProfileDataSource>((ref) {
  return UserProfileDataSource();
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(
    dataSource: ref.watch(userProfileDataSourceProvider),
  );
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);

  return repository.authStateChanges;
});

final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);

  if (authState == null) {
    return null;
  }

  final repository = ref.watch(userProfileRepositoryProvider);

  return repository.getUserByUid(authState.uid);
});