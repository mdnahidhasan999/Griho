import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'auth_route_guard.dart';
import 'auth_router_refresh.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static GoRouter create(Ref ref) {
    final guard = AuthRouteGuard(ref);
    final authRefresh = AuthRouterRefresh();

    ref.onDispose(authRefresh.dispose);

    return GoRouter(
      initialLocation: RouteNames.splash,

      refreshListenable: authRefresh,

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
      ],
    );
  }
}