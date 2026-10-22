import '../../domain/entities/app_user.dart';

enum AuthUserDestination {
  owner,
  tenant,
  manager,
  caretaker,
  completeProfile,
}

class AuthRoleResolver {
  AuthRoleResolver._();

  static AuthUserDestination resolve(AppUser user) {
    final phoneNumber = user.phoneNumber?.trim() ?? '';

    if (phoneNumber.isEmpty) {
      return AuthUserDestination.completeProfile;
    }

    switch (user.defaultDashboard?.trim().toLowerCase()) {
      case 'owner':
        return AuthUserDestination.owner;

      case 'tenant':
        return AuthUserDestination.tenant;

      case 'manager':
        return AuthUserDestination.manager;

      case 'caretaker':
        return AuthUserDestination.caretaker;

      default:
      // Unknown or unset dashboard values must not be treated as owner.
        return AuthUserDestination.completeProfile;
    }
  }
}