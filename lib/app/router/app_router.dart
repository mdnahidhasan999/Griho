import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';

import '../../features/home/presentation/screens/caretaker_home_screen.dart';
import '../../features/home/presentation/screens/manager_home_screen.dart';
import '../../features/home/presentation/screens/owner_home_screen.dart';

import '../../features/properties/domain/entities/property.dart';
import '../../features/properties/presentation/screens/add_property_screen.dart';
import '../../features/properties/presentation/screens/edit_property_screen.dart';
import '../../features/properties/presentation/screens/property_details_screen.dart';
import '../../features/properties/presentation/screens/property_list_screen.dart';

import '../../features/rents/presentation/screens/change_unit_rent_screen.dart';
import '../../features/rents/presentation/screens/monthly_rent_screen.dart';
import '../../features/rents/presentation/screens/rent_management_screen.dart';
import '../../features/rents/presentation/screens/rent_rate_history_screen.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';

import '../../features/tenants/domain/entities/tenant.dart';
import '../../features/tenants/presentation/screens/add_tenant_screen.dart';
import '../../features/tenants/presentation/screens/edit_tenant_screen.dart';
import '../../features/tenants/presentation/screens/owner_tenant_list_screen.dart';
import '../../features/tenants/presentation/screens/tenant_details_screen.dart';
import '../../features/tenants/presentation/screens/tenant_home_invitation_gate_screen.dart';
import '../../features/tenants/presentation/screens/tenant_invitation_receive_screen.dart';
import '../../features/tenants/presentation/screens/tenant_invitations_screen.dart';
import '../../features/tenants/presentation/screens/tenant_list_screen.dart';

import '../../features/units/domain/entities/unit.dart';
import '../../features/units/presentation/screens/add_unit_screen.dart';
import '../../features/units/presentation/screens/edit_unit_screen.dart';
import '../../features/units/presentation/screens/unit_details_screen.dart';
import '../../features/units/presentation/screens/unit_list_screen.dart';

import 'auth_route_guard.dart';
import 'auth_state_refresh_notifier.dart';
import 'route_arguments.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static GoRouter create(Ref ref) {
    final guard = AuthRouteGuard(ref);
    final authRefreshNotifier = AuthStateRefreshNotifier();

    return GoRouter(
      initialLocation: RouteNames.splash,

      refreshListenable: authRefreshNotifier,

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
        // LOGIN
        // ========================================================

        GoRoute(
          path: RouteNames.login,
          builder: (context, state) {
            final invitationId =
            state.uri.queryParameters['invitationId'];

            return PhoneLoginScreen(
              invitationId: invitationId,
            );
          },
        ),

        // ========================================================
        // OTP
        // ========================================================

        GoRoute(
          path: RouteNames.otpVerification,
          builder: (context, state) {
            final phoneNumber = state.extra as String?;

            if (phoneNumber == null ||
                phoneNumber.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid phone number.'),
                ),
              );
            }

            final invitationId =
            state.uri.queryParameters['invitationId'];

            return OtpVerificationScreen(
              phoneNumber: phoneNumber,
              invitationId: invitationId,
            );
          },
        ),

        // ========================================================
        // ONBOARDING
        // ========================================================

        GoRoute(
          path: RouteNames.onboarding,
          builder: (context, state) {
            return const OnboardingScreen();
          },
        ),

        // ========================================================
        // OWNER HOME
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
            final propertyId =
            state.pathParameters['propertyId'];

            if (propertyId == null ||
                propertyId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid property ID.'),
                ),
              );
            }

            return PropertyDetailsScreen(
              propertyId: propertyId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.editProperty,
          builder: (context, state) {
            final property = state.extra as Property?;

            if (property == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid property information.',
                  ),
                ),
              );
            }

            return EditPropertyScreen(
              property: property,
            );
          },
        ),

        // ========================================================
        // UNITS
        // ========================================================

        GoRoute(
          path: RouteNames.propertyUnits,
          builder: (context, state) {
            final propertyId =
            state.pathParameters['propertyId'];

            if (propertyId == null ||
                propertyId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid property ID.'),
                ),
              );
            }

            final arguments =
            state.extra as PropertyUnitsRouteArguments?;

            if (arguments == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid property information.',
                  ),
                ),
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
            final propertyId =
            state.pathParameters['propertyId'];

            if (propertyId == null ||
                propertyId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid property ID.'),
                ),
              );
            }

            final numberOfFloors =
            state.extra as int?;

            if (numberOfFloors == null ||
                numberOfFloors < 1) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid property floor information.',
                  ),
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
            final unitId =
            state.pathParameters['unitId'];

            if (unitId == null ||
                unitId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid unit ID.'),
                ),
              );
            }

            return UnitDetailsScreen(
              unitId: unitId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.editUnit,
          builder: (context, state) {
            final unit = state.extra as Unit?;

            if (unit == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid unit information.',
                  ),
                ),
              );
            }

            return EditUnitScreen(
              unit: unit,
            );
          },
        ),

        // ========================================================
        // RENT MANAGEMENT
        // ========================================================

        GoRoute(
          path: RouteNames.unitRentManagement,
          builder: (context, state) {
            final unitId =
            state.pathParameters['unitId'];

            if (unitId == null ||
                unitId.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid unit ID.'),
                ),
              );
            }

            return RentManagementScreen(
              unitId: unitId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.changeUnitRent,
          builder: (context, state) {
            final unitId =
            state.pathParameters['unitId'];

            if (unitId == null ||
                unitId.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid unit ID.'),
                ),
              );
            }

            return ChangeUnitRentScreen(
              unitId: unitId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.unitRentRateHistory,
          builder: (context, state) {
            final unitId =
            state.pathParameters['unitId'];

            if (unitId == null ||
                unitId.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid unit ID.'),
                ),
              );
            }

            return RentRateHistoryScreen(
              unitId: unitId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.unitMonthlyRent,
          builder: (context, state) {
            final unitId =
            state.pathParameters['unitId'];

            if (unitId == null ||
                unitId.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid unit ID.'),
                ),
              );
            }

            return MonthlyRentScreen(
              unitId: unitId,
            );
          },
        ),

        // ========================================================
        // TENANTS
        // ========================================================

        GoRoute(
          path: RouteNames.propertyTenants,
          builder: (context, state) {
            final propertyId =
            state.pathParameters['propertyId'];

            if (propertyId == null ||
                propertyId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid property ID.'),
                ),
              );
            }

            final arguments =
            state.extra as PropertyTenantsRouteArguments?;

            if (arguments == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid property information.',
                  ),
                ),
              );
            }

            return TenantListScreen(
              propertyId: propertyId,
              propertyName: arguments.propertyName,
            );
          },
        ),

        GoRoute(
          path: RouteNames.addTenant,
          builder: (context, state) {
            return const AddTenantScreen();
          },
        ),

        GoRoute(
          path: RouteNames.tenantDetails,
          builder: (context, state) {
            final tenantId =
            state.pathParameters['tenantId'];

            if (tenantId == null ||
                tenantId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid tenant ID.'),
                ),
              );
            }

            return TenantDetailsScreen(
              tenantId: tenantId,
            );
          },
        ),

        GoRoute(
          path: RouteNames.editTenant,
          builder: (context, state) {
            final tenantId =
            state.pathParameters['tenantId'];

            if (tenantId == null ||
                tenantId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Invalid tenant ID.'),
                ),
              );
            }

            final tenant = state.extra as Tenant?;

            if (tenant == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid tenant information.',
                  ),
                ),
              );
            }

            return EditTenantScreen(
              tenant: tenant,
            );
          },
        ),

        GoRoute(
          path: RouteNames.ownerTenants,
          builder: (context, state) {
            return const OwnerTenantListScreen();
          },
        ),

        // ========================================================
        // TENANT INVITATION
        // ========================================================

        GoRoute(
          path: RouteNames.tenantInvitation,
          name: 'tenantInvitation',
          builder: (context, state) {
            final invitationId =
            state.pathParameters['invitationId'];

            if (invitationId == null ||
                invitationId.trim().isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid invitation link.',
                  ),
                ),
              );
            }

            return TenantInvitationReceiveScreen(
              invitationId: invitationId,
            );
          },
        ),
// ========================================================

// TENANT INVITATIONS HISTORY

// ========================================================

        GoRoute(

          path: RouteNames.tenantInvitations,

          builder: (context, state) {

            return const TenantInvitationsScreen();

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

        // ========================================================
        // TENANT HOME
        // ========================================================

        GoRoute(
          path: RouteNames.tenantHome,
          builder: (context, state) {
            return const TenantHomeInvitationGateScreen();
          },
        ),

        // ========================================================
        // EDIT PROFILE
        // ========================================================

        GoRoute(
          path: RouteNames.editProfile,
          builder: (context, state) {
            final user = state.extra as AppUser;

            return EditProfileScreen(
              user: user,
            );
          },
        ),
      ],
    );
  }
}