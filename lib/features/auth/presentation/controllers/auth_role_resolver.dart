import '../../domain/entities/app_user.dart';

enum AuthUserDestination {
  owner,
  tenant,
  manager,
  caretaker,
  completeProfile,
}

class AuthRoleResolver {
  static AuthUserDestination resolve(AppUser user) {
    if (user.phoneNumber == null || user.phoneNumber!.trim().isEmpty) {
      return AuthUserDestination.completeProfile;
    }

    switch (user.defaultDashboard) {
      case 'tenant':
        return AuthUserDestination.tenant;
      case 'manager':
        return AuthUserDestination.manager;
      case 'caretaker':
        return AuthUserDestination.caretaker;
      case 'owner':
      default:
        return AuthUserDestination.owner;
    }
  }
}
