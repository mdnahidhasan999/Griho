// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../providers/auth_controller.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _completePhoneNumber = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final phoneNumber = PhoneNumberUtils.clean(_completePhoneNumber);

    if (!PhoneNumberUtils.isValid(phoneNumber)) {
      GrihoFeedback.showError(
        context,
        'Please enter a valid international phone number.',
      );
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .createAccountWithEmailAndPassword(
          name: _nameController.text.trim(),
          phoneNumber: phoneNumber,
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (!success) {
      final message = ref.read(authControllerProvider).errorMessage;
      GrihoFeedback.showError(
        context,
        message?.isNotEmpty == true
            ? message!
            : 'Unable to create your account. Please try again.',
      );
      return;
    }

    GrihoFeedback.showSuccess(context, 'Account created successfully.');
    context.go(RouteNames.linkWaiting, extra: _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GrihoIconBadge(icon: Iconsax.user_add),
                    const SizedBox(height: 22),
                    Text(
                      'Create Your Griho Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your details to get started.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GrihoTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      prefixIcon: Iconsax.user,
                      enabled: !authState.isLoading,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: GrihoValidators.name,
                    ),
                    const SizedBox(height: 16),
                    GrihoPhoneField(
                      controller: _phoneController,
                      enabled: !authState.isLoading,
                      onCompleteNumberChanged: (value) {
                        _completePhoneNumber = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    GrihoTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      prefixIcon: Iconsax.sms,
                      enabled: !authState.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: GrihoValidators.email,
                    ),
                    const SizedBox(height: 16),
                    GrihoPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      enabled: !authState.isLoading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: GrihoValidators.newPassword,
                    ),
                    const SizedBox(height: 16),
                    GrihoPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      prefixIcon: Iconsax.lock_1,
                      enabled: !authState.isLoading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!authState.isLoading) _createAccount();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password.';
                        }
                        if (value != _passwordController.text) {
                          return 'The passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 26),
                    GrihoPrimaryButton(
                      label: 'Create Account',
                      icon: Iconsax.user_tick,
                      isLoading: authState.isLoading,
                      onPressed: _createAccount,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => context.go(RouteNames.login),
                      child: const Text('Already have an account? Sign In'),
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
