// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_destination_mapper.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/auth_result.dart';
import '../controllers/auth_role_resolver.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? invitationId;

  const LoginScreen({super.key, this.invitationId});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (result == null) {
      final message = ref.read(authControllerProvider).errorMessage;
      GrihoFeedback.showError(
        context,
        message?.isNotEmpty == true
            ? message!
            : 'Unable to sign in. Please try again.',
      );
      return;
    }

    _navigateAfterAuthentication(result);
  }

  Future<void> _handleGoogleSignIn() async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    if (!mounted) return;

    if (result == null) {
      final message = ref.read(authControllerProvider).errorMessage;
      GrihoFeedback.showError(
        context,
        message?.isNotEmpty == true
            ? message!
            : 'Google Sign-In failed. Please try again.',
      );
      return;
    }

    _navigateAfterAuthentication(result);
  }

  void _navigateAfterAuthentication(AuthResult result) {
    if (!mounted) return;

    if (widget.invitationId != null && widget.invitationId!.trim().isNotEmpty) {
      context.go(RouteNames.tenantInvitationPath(widget.invitationId!));
      return;
    }

    if (result.isNewUser || result.user == null) {
      context.go(RouteNames.onboarding);
      return;
    }

    final destination = AuthRoleResolver.resolve(result.user!);
    context.go(AuthDestinationMapper.routeFor(destination));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: GrihoLogo(size: 64),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Griho',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your home and property information.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GrihoTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'name@example.com',
                      prefixIcon: Iconsax.sms,
                      enabled: !authState.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: GrihoValidators.email,
                    ),
                    const SizedBox(height: 16),
                    GrihoPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      enabled: !authState.isLoading,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!authState.isLoading) _handleEmailLogin();
                      },
                      validator: GrihoValidators.requiredPassword,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => context.go(RouteNames.forgotPassword),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GrihoPrimaryButton(
                      label: 'Sign In',
                      icon: Iconsax.login,
                      isLoading: authState.isLoading,
                      onPressed: _handleEmailLogin,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GrihoSecondaryButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: authState.isLoading
                          ? null
                          : _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Don’t have an account?',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: authState.isLoading
                              ? null
                              : () => context.go(RouteNames.createAccount),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
