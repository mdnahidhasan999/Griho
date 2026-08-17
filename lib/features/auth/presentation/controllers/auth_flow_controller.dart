import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../providers/auth_provider.dart';
import 'auth_role_resolver.dart';

final authFlowControllerProvider = Provider<AuthFlowController>((ref) {
  return AuthFlowController(ref);
});

class AuthFlowController {
  final Ref ref;

  const AuthFlowController(this.ref);

  Future<AuthFlowResult> resolve() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const AuthFlowResult.unauthenticated();
    }

    final profile = await ref.read(
      userProfileRepositoryProvider,
    ).getUserByUid(firebaseUser.uid);

    if (profile == null) {
      return const AuthFlowResult.newUser();
    }

    final destination = AuthRoleResolver.resolve(
      profile.role,
    );

    return AuthFlowResult.existingUser(
      profile,
      destination,
    );
  }
}

enum AuthFlowStatus {
  unauthenticated,
  newUser,
  existingUser,
}

class AuthFlowResult {
  final AuthFlowStatus status;
  final AppUser? user;
  final AuthUserDestination? destination;

  const AuthFlowResult._({
    required this.status,
    this.user,
    this.destination,
  });

  const AuthFlowResult.unauthenticated()
      : this._(
    status: AuthFlowStatus.unauthenticated,
  );

  const AuthFlowResult.newUser()
      : this._(
    status: AuthFlowStatus.newUser,
  );

  const AuthFlowResult.existingUser(
      AppUser user,
      AuthUserDestination destination,
      ) : this._(
    status: AuthFlowStatus.existingUser,
    user: user,
    destination: destination,
  );
}