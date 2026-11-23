// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../providers/auth_controller.dart';

class LinkWaitingScreen extends ConsumerStatefulWidget {
  final String email;

  const LinkWaitingScreen({super.key, required this.email});

  @override
  ConsumerState<LinkWaitingScreen> createState() => _LinkWaitingScreenState();
}

class _LinkWaitingScreenState extends ConsumerState<LinkWaitingScreen> {
  final TextEditingController _linkController = TextEditingController();

  bool _autoVerificationStarted = false;
  bool _verificationSucceeded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleIncomingVerificationLink();
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _handleIncomingVerificationLink() async {
    if (_autoVerificationStarted) return;
    _autoVerificationStarted = true;

    final Uri incomingUri = Uri.base;
    final String? mode = incomingUri.queryParameters['mode'];
    final String? oobCode = incomingUri.queryParameters['oobCode'];

    if (mode != 'verifyEmail' || oobCode == null || oobCode.trim().isEmpty) {
      return;
    }

    _linkController.text = incomingUri.toString();
    await _verifyEmailCode(oobCode.trim());
  }

  String? _extractVerificationCode(String input) {
    final String value = input.trim();
    if (value.isEmpty) return null;

    final Uri? uri = Uri.tryParse(value);

    if (uri == null) {
      if (!value.contains('://') && !value.contains('?')) {
        return value;
      }
      return null;
    }

    final String? directCode = uri.queryParameters['oobCode'];
    if (directCode != null && directCode.isNotEmpty) {
      return directCode;
    }

    final String? nestedLink = uri.queryParameters['link'];
    if (nestedLink != null && nestedLink.isNotEmpty) {
      final Uri? nestedUri = Uri.tryParse(nestedLink);
      final String? nestedCode = nestedUri?.queryParameters['oobCode'];
      if (nestedCode != null && nestedCode.isNotEmpty) {
        return nestedCode;
      }
    }

    return null;
  }

  Future<void> _verifyPastedLink() async {
    FocusScope.of(context).unfocus();
    final String input = _linkController.text.trim();

    if (input.isEmpty) {
      GrihoFeedback.showError(
        context,
        'Please paste the email verification link.',
      );
      return;
    }

    final String? code = _extractVerificationCode(input);

    if (code == null || code.isEmpty) {
      GrihoFeedback.showError(
        context,
        'The verification link is invalid. Please copy the complete link from the latest email.',
      );
      return;
    }

    await _verifyEmailCode(code);
  }

  Future<void> _verifyEmailCode(String code) async {
    if (!mounted) return;

    final bool success = await ref
        .read(authControllerProvider.notifier)
        .handleEmailVerificationCode(code);

    if (!mounted) return;

    if (!success) {
      final String errorMessage =
          ref.read(authControllerProvider).errorMessage ??
          'Email verification failed. The link may have expired.';
      GrihoFeedback.showError(context, errorMessage);
      return;
    }

    setState(() => _verificationSucceeded = true);

    GrihoFeedback.showSuccess(
      context,
      'Email verified successfully. You can now sign in.',
    );

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrihoIconBadge(
                    icon: _verificationSucceeded
                        ? Iconsax.verify
                        : Iconsax.sms_tracking,
                    isSuccess: _verificationSucceeded,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _verificationSucceeded
                        ? 'Email Verified!'
                        : 'Verify Your Email',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _verificationSucceeded
                        ? 'Your email address has been verified. You can now sign in to Griho using your email and password.'
                        : 'We sent an email verification link to your registered email address.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.email.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.email.trim(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_verificationSucceeded) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        'Open the verification email and click the verification link. If the link does not open Griho automatically, copy the complete link and paste it below.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GrihoTextField(
                      controller: _linkController,
                      label: 'Verification Link',
                      hint: 'Paste the complete email verification link',
                      prefixIcon: Iconsax.link,
                      enabled: !authState.isLoading,
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 20),
                    GrihoPrimaryButton(
                      label: 'Verify Email',
                      icon: Iconsax.verify,
                      isLoading: authState.isLoading,
                      onPressed: _verifyPastedLink,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => context.go(RouteNames.login),
                      child: const Text('Back to Sign In'),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    const GrihoLoadingView(message: 'Returning to sign in...'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
