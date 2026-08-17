import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import 'route_names.dart';

abstract final class AuthDestinationMapper {
  static String routeFor(AuthUserDestination destination) {
    switch (destination) {
      case AuthUserDestination.owner:
        return RouteNames.ownerHome;

      case AuthUserDestination.manager:
        return RouteNames.managerHome;

      case AuthUserDestination.caretaker:
        return RouteNames.caretakerHome;

      case AuthUserDestination.tenant:
        return RouteNames.tenantHome;
    }
  }
}