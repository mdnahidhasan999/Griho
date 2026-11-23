// noinspection SpellCheckingInspection
enum GrihoRole { owner, tenant, manager, caretaker }

extension GrihoRoleExtension on GrihoRole {
  String get key => switch (this) {
    GrihoRole.owner => 'owner',
    GrihoRole.tenant => 'tenant',
    GrihoRole.manager => 'manager',
    GrihoRole.caretaker => 'caretaker',
  };

  String get label => switch (this) {
    GrihoRole.owner => 'Owner',
    GrihoRole.tenant => 'Tenant',
    GrihoRole.manager => 'Manager',
    GrihoRole.caretaker => 'Caretaker',
  };

  static GrihoRole? fromKey(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'owner' => GrihoRole.owner,
      'tenant' => GrihoRole.tenant,
      'manager' => GrihoRole.manager,
      'caretaker' => GrihoRole.caretaker,
      _ => null,
    };
  }
}

class RoleNavigationConfig {
  const RoleNavigationConfig({required this.role, required this.homeRoute});

  final GrihoRole role;
  final String homeRoute;
}
