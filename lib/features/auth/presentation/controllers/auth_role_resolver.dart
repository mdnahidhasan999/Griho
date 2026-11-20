import '../../domain/entities/app_user.dart';

enum AuthUserDestination {
  owner,
  tenant,
  manager,
  caretaker,
  electrician,
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
      final destination = _destinationForRole(defaultDashboard);
      if (destination != null) {
        return destination;
      }
    }

    // If the user has only a single role, route directly to it even if
    // defaultDashboard was unset or stale.
    if (availableRoles.length == 1) {
      final destination = _destinationForRole(availableRoles.first);
      if (destination != null) {
        return destination;
      }
    }

    return AuthUserDestination.roleSelection;
  }

  static AuthUserDestination? _destinationForRole(String role) {
    switch (role) {
      case 'owner':
        return AuthUserDestination.owner;
      case 'tenant':
        return AuthUserDestination.tenant;
      case 'manager':
        return AuthUserDestination.manager;
      case 'caretaker':
        return AuthUserDestination.caretaker;
      case 'electrician':
        return AuthUserDestination.electrician;
      default:
        return null;
    }
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
