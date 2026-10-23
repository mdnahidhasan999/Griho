import '../../domain/entities/app_user.dart';

enum AuthUserDestination {
  owner,
  tenant,
  manager,
  caretaker,
  roleSelection,
  completeProfile,
}

class AuthRoleResolver {
  AuthRoleResolver._();

  static AuthUserDestination resolve(AppUser user) {
    final phoneNumber = user.phoneNumber?.trim() ?? '';

    if (phoneNumber.isEmpty) {
      return AuthUserDestination.completeProfile;
    }

    final availableRoles = user.availableRoles
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty)
        .toSet();

    if (availableRoles.isEmpty) {
      return AuthUserDestination.roleSelection;
    }

    final defaultDashboard = user.defaultDashboard?.trim().toLowerCase();

    if (defaultDashboard != null && availableRoles.contains(defaultDashboard)) {
      switch (defaultDashboard) {
        case 'owner':
          return AuthUserDestination.owner;

        case 'tenant':
          return AuthUserDestination.tenant;

        case 'manager':
          return AuthUserDestination.manager;

        case 'caretaker':
          return AuthUserDestination.caretaker;
      }
    }

    // A default dashboard must be an authorized role.
    // Otherwise, send the user to role selection.
    return AuthUserDestination.roleSelection;
  }

  static bool canAccessRole(AppUser user, String role) {
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole.isEmpty) {
      return false;
    }

    return user.availableRoles.any(
      (availableRole) => availableRole.trim().toLowerCase() == normalizedRole,
    );
  }
}
