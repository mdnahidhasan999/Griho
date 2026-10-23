enum GrihoRole {
  owner,
  tenant,
  manager,
  caretaker,
}

extension GrihoRoleExtension on GrihoRole {
  String get key {
    switch (this) {
      case GrihoRole.owner:
        return 'owner';
      case GrihoRole.tenant:
        return 'tenant';
      case GrihoRole.manager:
        return 'manager';
      case GrihoRole.caretaker:
        return 'caretaker';
    }
  }

  String get label {
    switch (this) {
      case GrihoRole.owner:
        return 'Owner';
      case GrihoRole.tenant:
        return 'Tenant';
      case GrihoRole.manager:
        return 'Manager';
      case GrihoRole.caretaker:
        return 'Caretaker';
    }
  }

  static GrihoRole? fromKey(String? value) {
    switch (value) {
      case 'owner':
        return GrihoRole.owner;
      case 'tenant':
        return GrihoRole.tenant;
      case 'manager':
        return GrihoRole.manager;
      case 'caretaker':
        return GrihoRole.caretaker;
      default:
        return null;
    }
  }
}

class RoleNavigationConfig {
  const RoleNavigationConfig({
    required this.role,
    required this.homeRoute,
  });

  final GrihoRole role;
  final String homeRoute;
}