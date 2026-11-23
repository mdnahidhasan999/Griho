// noinspection SpellCheckingInspection
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../providers/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _completePhoneNumber = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    _emailController.text = firebaseUser?.email ?? '';
    _nameController.text = firebaseUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      GrihoFeedback.showError(
        context,
        'Your session has expired. Please sign in again.',
      );
      context.go(RouteNames.login);
      return;
    }

    final String? email = firebaseUser.email;
    if (email == null || email.trim().isEmpty) {
      GrihoFeedback.showError(
        context,
        'Your account does not have an email address. Please sign in again.',
      );
      return;
    }

    final bool usesEmailPassword = firebaseUser.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (usesEmailPassword && !firebaseUser.emailVerified) {
      GrihoFeedback.showError(
        context,
        'Please verify your email address before completing your profile.',
      );

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go(RouteNames.login);
      return;
    }

    final String phoneNumber = PhoneNumberUtils.clean(_completePhoneNumber);
    if (!PhoneNumberUtils.isValid(phoneNumber)) {
      GrihoFeedback.showError(
        context,
        'Please enter a valid permanent phone number.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await ref
          .read(authControllerProvider.notifier)
          .completeUserProfile(
            name: _nameController.text.trim(),
            phoneNumber: phoneNumber,
          );

      if (!mounted) return;

      if (user == null) {
        final String message =
            ref.read(authControllerProvider).errorMessage ??
            'Unable to complete your profile. Please try again.';
        GrihoFeedback.showError(context, message);
        return;
      }

      GrihoFeedback.showSuccess(
        context,
        'Your profile has been completed successfully.',
      );

      context.go(RouteNames.roleSelection);
    } catch (_) {
      if (!mounted) return;
      GrihoFeedback.showError(
        context,
        'Unable to complete your profile. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final bool isLoading = _isSubmitting || authState.isLoading;

    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final bool emailVerified = firebaseUser?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GrihoIconBadge(icon: Iconsax.user_add),
                    const SizedBox(height: 22),
                    Text(
                      'Almost There!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your profile to continue using Griho. Your account details will be associated with your profile.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    GrihoTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      prefixIcon: Iconsax.user,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: GrihoValidators.name,
                    ),
                    const SizedBox(height: 16),
                    GrihoTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      prefixIcon: Iconsax.sms,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      suffixIcon: Icon(
                        emailVerified ? Iconsax.verify : Iconsax.info_circle,
                        size: 20,
                        color: emailVerified
                            ? GrihoColors.emerald
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your email address is managed by your sign-in provider.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GrihoPhoneField(
                      controller: _phoneController,
                      label: 'Permanent Phone Number',
                      hint: 'Enter your phone number',
                      enabled: !isLoading,
                      onCompleteNumberChanged: (value) {
                        _completePhoneNumber = value;
                      },
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Iconsax.info_circle,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use your permanent phone number. Griho uses it to identify your profile.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Iconsax.shield_security,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You do not need to select an account role here. Your access will be determined by your Griho account and any applicable property invitation.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.45,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    GrihoPrimaryButton(
                      label: 'Complete Profile',
                      icon: Iconsax.tick_circle,
                      isLoading: isLoading,
                      onPressed: _completeProfile,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(RouteNames.login),
                      child: const Text('Back to Sign In'),
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
