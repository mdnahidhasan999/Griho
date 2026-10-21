import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_destination_mapper.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../auth/presentation/controllers/auth_role_resolver.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    if (_isChecking) {
      return;
    }

    _isChecking = true;

    try {
      debugPrint('SPLASH: Checking authentication status...');

      final results = await Future.wait([
        _resolveUserDestination(),
        Future<void>.delayed(const Duration(milliseconds: 800)),
      ]);

      final targetRoute = results.first as String;

      if (!mounted) {
        return;
      }

      debugPrint('SPLASH: Navigating to $targetRoute');
      context.go(targetRoute);
    } catch (error, stackTrace) {
      debugPrint('SPLASH ERROR: $error');
      debugPrint('SPLASH STACK: $stackTrace');

      if (!mounted) {
        return;
      }

      context.go(RouteNames.login);
    } finally {
      _isChecking = false;
    }
  }

  Future<String> _resolveUserDestination() async {
    final repository = ref.read(authRepositoryProvider);
    final firebaseUser = repository.currentUser;

    if (firebaseUser == null) {
      debugPrint('SPLASH: No authenticated Firebase session found.');
      return RouteNames.login;
    }

    debugPrint('SPLASH: Firebase user verified: ${firebaseUser.uid}');

    final profile = await ref
        .read(userProfileRepositoryProvider)
        .getUserByUid(firebaseUser.uid);

    if (profile == null) {
      debugPrint(
          'SPLASH: User profile not created yet. Redirecting to onboarding.');
      return RouteNames.onboarding;
    }

    // ফিক্স: profile.role এর জায়গায় defaultDashboard প্রিন্ট করা হয়েছে
    debugPrint('SPLASH: Profile identified: ${profile
        .publicId} (Default View: ${profile.defaultDashboard})');

    // ফিক্স: profile.role এর বদলে সরাসরি profile পাস করা হয়েছে
    final destination = AuthRoleResolver.resolve(profile);
    return AuthDestinationMapper.routeFor(destination);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Brand Logo Mark
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Title
                  Text(
                    'Griho',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Tagline
                  Text(
                    'Manage Every Home with Confidence',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Loading Indicator
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Footer Security Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Secure Property Management',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
