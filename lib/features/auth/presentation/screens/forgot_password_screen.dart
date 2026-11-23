// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../providers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
    } else {
      final message = ref.read(authControllerProvider).errorMessage;
      GrihoFeedback.showError(
        context,
        message?.isNotEmpty == true
            ? message!
            : 'Unable to send the password reset email. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _emailSent
                  ? _buildSuccessContent(theme)
                  : _buildForm(theme, authState.isLoading),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrihoIconBadge(icon: Iconsax.key),
          const SizedBox(height: 24),
          Text(
            'Forgot Your Password?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the email address associated with your Griho account and we’ll send you a link to reset your password.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          GrihoTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'name@example.com',
            prefixIcon: Iconsax.sms,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!isLoading) _sendResetEmail();
            },
            validator: GrihoValidators.email,
          ),
          const SizedBox(height: 24),
          GrihoPrimaryButton(
            label: 'Send Reset Link',
            icon: Iconsax.send_2,
            isLoading: isLoading,
            onPressed: _sendResetEmail,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: isLoading ? null : () => context.go(RouteNames.login),
            icon: const Icon(Iconsax.arrow_left, size: 18),
            label: const Text('Back to Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GrihoIconBadge(icon: Iconsax.sms_tracking, isSuccess: true),
        const SizedBox(height: 24),
        Text(
          'Check Your Email',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'If an account exists for ${_emailController.text.trim()}, a password reset email will be sent. Check your inbox and spam folder.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.55,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        GrihoPrimaryButton(
          label: 'Back to Sign In',
          icon: Iconsax.login,
          onPressed: () => context.go(RouteNames.login),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text('Try Another Email'),
        ),
      ],
    );
  }
}
