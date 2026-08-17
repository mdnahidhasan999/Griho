import 'app_user.dart';

class AuthResult {
  final bool isNewUser;
  final AppUser? user;

  const AuthResult({
    required this.isNewUser,
    this.user,
  });

  const AuthResult.newUser()
      : isNewUser = true,
        user = null;

  const AuthResult.existingUser(this.user)
      : isNewUser = false;
}