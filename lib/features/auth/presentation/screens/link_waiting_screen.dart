import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../providers/auth_controller.dart';

class LinkWaitingScreen extends ConsumerStatefulWidget {
  final String email;

  const LinkWaitingScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<LinkWaitingScreen> createState() =>
      _LinkWaitingScreenState();
}

class _LinkWaitingScreenState extends ConsumerState<LinkWaitingScreen> {
  final TextEditingController _linkController =
  TextEditingController();

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

  /// Automatically handles a Firebase email verification link
  /// when the verification URL is opened inside the app.
  Future<void> _handleIncomingVerificationLink() async {
    if (_autoVerificationStarted) return;

    _autoVerificationStarted = true;

    final Uri incomingUri = Uri.base;
    final String? mode = incomingUri.queryParameters['mode'];
    final String? oobCode =
    incomingUri.queryParameters['oobCode'];

    if (mode != 'verifyEmail' ||
        oobCode == null ||
        oobCode
            .trim()
            .isEmpty) {
      return;
    }

    _linkController.text = incomingUri.toString();

    await _verifyEmailCode(oobCode.trim());
  }

  /// Extracts the Firebase verification code from a pasted URL.
  String? _extractVerificationCode(String input) {
    final String value = input.trim();

    if (value.isEmpty) return null;

    final Uri? uri = Uri.tryParse(value);

    if (uri == null) {
      // Allow a raw Firebase action code to be pasted.
      if (!value.contains('://') && !value.contains('?')) {
        return value;
      }

      return null;
    }

    final String? directCode =
    uri.queryParameters['oobCode'];

    if (directCode != null && directCode.isNotEmpty) {
      return directCode;
    }

    // Some Firebase email action URLs contain a nested link.
    final String? nestedLink =
    uri.queryParameters['link'];

    if (nestedLink != null && nestedLink.isNotEmpty) {
      final Uri? nestedUri = Uri.tryParse(nestedLink);

      final String? nestedCode =
      nestedUri?.queryParameters['oobCode'];

      if (nestedCode != null && nestedCode.isNotEmpty) {
        return nestedCode;
      }
    }

    return null;
  }

  Future<void> _verifyPastedLink() async {
    final String input = _linkController.text.trim();

    if (input.isEmpty) {
      _showMessage(
        'Please paste the email verification link.',
        isError: true,
      );
      return;
    }

    final String? code = _extractVerificationCode(input);

    if (code == null || code.isEmpty) {
      _showMessage(
        'The verification link is invalid. Please open the latest email and copy the complete verification link.',
        isError: true,
      );
      return;
    }

    await _verifyEmailCode(code);
  }

  /// Applies the Firebase email verification action code.
  Future<void> _verifyEmailCode(String code) async {
    if (!mounted) return;

    final bool success = await ref
        .read(authControllerProvider.notifier)
        .handleEmailVerificationCode(code);

    if (!mounted) return;

    if (!success) {
      final String errorMessage =
          ref
              .read(authControllerProvider)
              .errorMessage ??
              'Email verification failed. The link may have expired. Please request a new verification email.';

      _showMessage(errorMessage, isError: true);
      return;
    }

    setState(() {
      _verificationSucceeded = true;
    });

    _showMessage(
      'Email verified successfully. You can now sign in.',
      isError: false,
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Email verification must not automatically sign the user in.
    context.go(RouteNames.login);
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
          backgroundColor: isError
              ? Theme
              .of(context)
              .colorScheme
              .error
              : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _verificationSucceeded
                          ? Colors.green.withValues(alpha: 0.12)
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      _verificationSucceeded
                          ? Icons.verified_rounded
                          : Icons.mark_email_read_rounded,
                      size: 40,
                      color: _verificationSucceeded
                          ? Colors.green
                          : theme.colorScheme.onPrimaryContainer,
                    ),
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
                  const SizedBox(height: 12),
                  Text(
                    _verificationSucceeded
                        ? 'Your email address has been verified. You can now sign in to Griho using your email and password.'
                        : 'We sent an email verification link to your registered email address.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.email
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                        color: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Open the verification email and click the verification link. If the link does not open Griho automatically, copy the complete link and paste it below.',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verification Link',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _linkController,
                      enabled: !authState.isLoading,
                      minLines: 2,
                      maxLines: 5,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText:
                        'Paste the complete email verification link',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: authState.isLoading
                            ? null
                            : _verifyPastedLink,
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
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Returning to sign in...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  const SizedBox(height: 20),
                  if (!_verificationSucceeded)
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
    );
  }
}