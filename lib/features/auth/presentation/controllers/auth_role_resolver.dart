import '../../domain/entities/app_user.dart';

abstract final class AuthRoleResolver {
  static AuthUserDestination resolve(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return AuthUserDestination.owner;

      case UserRole.manager:
        return AuthUserDestination.manager;

      case UserRole.caretaker:
        return AuthUserDestination.caretaker;

      case UserRole.tenant:
        return AuthUserDestination.tenant;
    }
  }
}

enum AuthUserDestination {
  owner,
  manager,
  caretaker,
  tenant,
}