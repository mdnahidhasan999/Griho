import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:griho/app/router/route_arguments.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';

import '../../features/home/presentation/screens/caretaker_home_screen.dart';
import '../../features/home/presentation/screens/manager_home_screen.dart';
import '../../features/home/presentation/screens/owner_home_screen.dart';
import '../../features/home/presentation/screens/tenant_home_screen.dart';

import '../../features/properties/domain/entities/property.dart';
import '../../features/properties/presentation/screens/add_property_screen.dart';
import '../../features/properties/presentation/screens/edit_property_screen.dart';
import '../../features/properties/presentation/screens/property_details_screen.dart';
import '../../features/properties/presentation/screens/property_list_screen.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';

import '../../features/units/domain/entities/unit.dart';
import '../../features/units/presentation/screens/add_unit_screen.dart';
import '../../features/units/presentation/screens/edit_unit_screen.dart';
import '../../features/units/presentation/screens/unit_details_screen.dart';
import '../../features/units/presentation/screens/unit_list_screen.dart';

import 'auth_route_guard.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static GoRouter create(Ref ref) {
    final guard = AuthRouteGuard(ref);

    return GoRouter(
      initialLocation: RouteNames.splash,

      redirect: (context, state) {
        return guard.redirect(state.uri.path);
      },

      routes: [
        // ========================================================
        // SPLASH
        // ========================================================
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) {
            return const SplashScreen();
          },
        ),

        // ========================================================
        // AUTH
        // ========================================================
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) {
            return const PhoneLoginScreen();
          },
        ),

        GoRoute(
          path: RouteNames.otpVerification,
          builder: (context, state) {
            final phoneNumber = state.extra as String;

            return OtpVerificationScreen(phoneNumber: phoneNumber);
          },
        ),

        GoRoute(
          path: RouteNames.onboarding,
          builder: (context, state) {
            return const OnboardingScreen();
          },
        ),

        // ========================================================
        // OWNER
        // ========================================================
        GoRoute(
          path: RouteNames.ownerHome,
          builder: (context, state) {
            return const OwnerHomeScreen();
          },
        ),

        // ========================================================
        // PROPERTY
        // ========================================================
        GoRoute(
          path: RouteNames.addProperty,
          builder: (context, state) {
            return const AddPropertyScreen();
          },
        ),

        GoRoute(
          path: RouteNames.propertyList,
          builder: (context, state) {
            return const PropertyListScreen();
          },
        ),

        GoRoute(
          path: RouteNames.propertyDetails,
          builder: (context, state) {
            final propertyId = state.pathParameters['propertyId'];

            if (propertyId == null || propertyId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('Invalid property ID.')),
              );
            }

            return PropertyDetailsScreen(propertyId: propertyId);
          },
        ),

        GoRoute(
          path: RouteNames.editProperty,
          builder: (context, state) {
            final property = state.extra as Property;

            return EditPropertyScreen(property: property);
          },
        ),

        // ========================================================
        // UNITS
        // ========================================================
        GoRoute(
          path: RouteNames.propertyUnits,
          builder: (context, state) {
            final propertyId = state.pathParameters['propertyId'];

            if (propertyId == null || propertyId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('Invalid property ID.')),
              );
            }

            final arguments = state.extra as PropertyUnitsRouteArguments?;

            if (arguments == null) {
              return const Scaffold(
                body: Center(child: Text('Invalid property information.')),
              );
            }

            return UnitListScreen(
              propertyId: propertyId,
              propertyName: arguments.propertyName,
              numberOfFloors: arguments.numberOfFloors,
            );
          },
        ),

        GoRoute(
          path: RouteNames.addUnit,
          builder: (context, state) {
            final propertyId = state.pathParameters['propertyId'];

            if (propertyId == null || propertyId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('Invalid property ID.')),
              );
            }

            final numberOfFloors = state.extra as int?;

            if (numberOfFloors == null || numberOfFloors < 1) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid property floor information.'),
                ),
              );
            }

            return AddUnitScreen(
              propertyId: propertyId,
              numberOfFloors: numberOfFloors,
            );
          },
        ),

        GoRoute(
          path: RouteNames.unitDetails,
          builder: (context, state) {
            final unitId = state.pathParameters['unitId'];

            if (unitId == null || unitId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('Invalid unit ID.')),
              );
            }

            return UnitDetailsScreen(unitId: unitId);
          },
        ),

        GoRoute(
          path: RouteNames.editUnit,
          builder: (context, state) {
            final unit = state.extra as Unit;

            return EditUnitScreen(unit: unit);
          },
        ),

        // ========================================================
        // OTHER ROLES
        // ========================================================
        GoRoute(
          path: RouteNames.managerHome,
          builder: (context, state) {
            return const ManagerHomeScreen();
          },
        ),

        GoRoute(
          path: RouteNames.caretakerHome,
          builder: (context, state) {
            return const CaretakerHomeScreen();
          },
        ),

        GoRoute(
          path: RouteNames.tenantHome,
          builder: (context, state) {
            return const TenantHomeScreen();
          },
        ),
      ],
    );
  }
}
