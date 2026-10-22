import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController =
  TextEditingController();
  final TextEditingController _emailController =
  TextEditingController();

  String _completePhoneNumber = '';

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
    super.dispose();
  }

  Future<void> _completeProfile() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String phoneNumber =
    PhoneNumberUtils.clean(_completePhoneNumber);

    if (!PhoneNumberUtils.isValid(phoneNumber)) {
      _showMessage(
        'Please enter a valid permanent phone number.',
        isError: true,
      );
      return;
    }

    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      _showMessage(
        'Your session has expired. Please sign in again.',
        isError: true,
      );

      context.go(RouteNames.login);
      return;
    }

    if (firebaseUser.email == null ||
        firebaseUser.email!.trim().isEmpty) {
      _showMessage(
        'Your account does not have an email address. Please sign in again.',
        isError: true,
      );
      return;
    }

    final bool usesEmailPassword = firebaseUser.providerData.any(
          (provider) => provider.providerId == 'password',
    );

    if (usesEmailPassword && !firebaseUser.emailVerified) {
      _showMessage(
        'Please verify your email address before completing your profile.',
        isError: true,
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      context.go(RouteNames.login);
      return;
    }

    final user = await ref
        .read(authControllerProvider.notifier)
        .completeUserProfile(
      name: _nameController.text.trim(),
      phoneNumber: phoneNumber,
    );

    if (!mounted) return;

    if (user == null) {
      final String message =
          ref
              .read(authControllerProvider)
              .errorMessage ??
              'Unable to complete your profile. Please try again.';

      _showMessage(message, isError: true);
      return;
    }

    _showMessage(
      'Your profile has been completed successfully.',
      isError: false,
    );

    // Refresh the profile before routing to the next screen.
    await ref.read(currentUserProfileProvider.future);

    if (!mounted) return;

    context.go(RouteNames.splash);
  }

  void _showMessage(String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? Theme
              .of(context)
              .colorScheme
              .error : Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
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
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Almost There!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your profile to continue using Griho. '
                          'Your account details will be associated with your profile.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _FieldLabel(
                      label: 'Full Name',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !authState.isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon:
                        Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Please enter your full name.';
                        }

                        if (value
                            .trim()
                            .length < 2) {
                          return 'Name must contain at least 2 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _FieldLabel(
                      label: 'Email Address',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon:
                        const Icon(Icons.mail_outline_rounded),
                        suffixIcon: Icon(
                          Icons.verified_rounded,
                          color: Colors.green.shade700,
                        ),
                        filled: true,
                        fillColor: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your email address is managed by your sign-in provider.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _FieldLabel(
                      label: 'Permanent Phone Number',
                    ),
                    const SizedBox(height: 8),
                    IntlPhoneField(
                      initialCountryCode: 'BD',
                      enabled: !authState.isLoading,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Enter your phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                      onChanged: (phone) {
                        _completePhoneNumber = phone.completeNumber;
                      },
                      validator: (phone) {
                        if (phone == null ||
                            phone.number
                                .trim()
                                .isEmpty) {
                          return 'Permanent phone number is required.';
                        }

                        if (!phone.isValidNumber()) {
                          return 'Please enter a valid phone number.';
                        }

                        return null;
                      },
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use your permanent phone number. '
                                'Griho uses it to identify your profile.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'You do not need to select an account role here. '
                                  'Your access will be determined by your Griho account '
                                  'and any applicable property invitation.',
                              style: TextStyle(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: authState.isLoading
                            ? null
                            : _completeProfile,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Complete Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: authState.isLoading
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

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme
          .of(context)
          .textTheme
          .titleSmall
          ?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}