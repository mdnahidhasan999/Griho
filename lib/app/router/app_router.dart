import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/home/presentation/screens/caretaker_home_screen.dart';
import '../../features/home/presentation/screens/manager_home_screen.dart';
import '../../features/home/presentation/screens/owner_home_screen.dart';
import '../../features/home/presentation/screens/tenant_home_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'auth_route_guard.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static GoRouter create(Ref ref) {
    final guard = AuthRouteGuard(ref);

    return GoRouter(
      initialLocation: RouteNames.splash,

      redirect: (context, state) {
        return guard.redirect(
          state.uri.path,
        );
      },

      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) {
            return const SplashScreen();
          },
        ),

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

            return OtpVerificationScreen(
              phoneNumber: phoneNumber,
            );
          },
        ),

        GoRoute(
          path: RouteNames.onboarding,
          builder: (context, state) {
            return const OnboardingScreen();
          },
        ),



        GoRoute(
          path: RouteNames.ownerHome,
          builder: (context, state) {
            return const OwnerHomeScreen();
          },
        ),

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