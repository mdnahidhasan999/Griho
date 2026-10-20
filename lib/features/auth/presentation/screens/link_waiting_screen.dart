import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/router/route_names.dart';
import '../providers/auth_controller.dart';

class LinkWaitingScreen extends ConsumerStatefulWidget {
  final String email;

  const LinkWaitingScreen({super.key, required this.email});

  @override
  ConsumerState<LinkWaitingScreen> createState() => _LinkWaitingScreenState();
}

class _LinkWaitingScreenState extends ConsumerState<LinkWaitingScreen> {
  final _linkController = TextEditingController();
  final _emailController = TextEditingController();

  bool _autoVerificationStarted = false;
  bool _requiresEmail = false;
  bool _verificationFailed = false;

  @override
  void initState() {
    super.initState();

    _emailController.text = widget.email;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleIncomingEmailLink();
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleIncomingEmailLink() async {
    if (_autoVerificationStarted) return;
    _autoVerificationStarted = true;

    final incomingLink = Uri.base.toString();

    debugPrint('EMAIL LINK DEBUG: Current URL: ${Uri.base}');
    debugPrint('EMAIL LINK DEBUG: URL path: ${Uri.base.path}');
    debugPrint(
      'EMAIL LINK DEBUG: Has mode parameter: '
      '${Uri.base.queryParameters.containsKey('mode')}',
    );
    debugPrint(
      'EMAIL LINK DEBUG: Has oobCode parameter: '
      '${Uri.base.queryParameters.containsKey('oobCode')}',
    );

    final isEmailLink = FirebaseAuthLinkCheck.isEmailLink(incomingLink);

    debugPrint('EMAIL LINK DEBUG: Firebase recognized link: $isEmailLink');

    if (!isEmailLink) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The email link could not be recognized. Please try a new link.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    _linkController.text = incomingLink;

    var email = widget.email.trim();

    if (email.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      email = prefs.getString('emailForSignIn')?.trim() ?? '';
    }

    if (email.isEmpty) {
      if (!mounted) return;

      setState(() {
        _requiresEmail = true;
      });

      return;
    }

    await _verifyLink(email: email, link: incomingLink);
  }

  Future<void> _verifyLink({
    required String email,
    required String link,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      setState(() {
        _requiresEmail = true;
      });
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyEmailLink(email: normalizedEmail, emailLink: link.trim());

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email link verified successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      context.go(RouteNames.splash);
    } else {
      setState(() {
        _verificationFailed = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authControllerProvider).errorMessage ??
                'The link is invalid or has expired. Please request a new one.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyPastedLink() async {
    final link = _linkController.text.trim();
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the email address used to request the link.',
          ),
        ),
      );
      return;
    }

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste the magic link.')),
      );
      return;
    }

    await _verifyLink(email: email, link: link);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Check Your Email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a Magic Link to:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email.isEmpty
                    ? 'Enter the email address below'
                    : widget.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Open the email and click the Magic Link. '
                  'Griho will try to verify the link automatically. '
                  'If automatic verification is unavailable, you can paste the link below.',
                  style: TextStyle(height: 1.4),
                ),
              ),
              const SizedBox(height: 28),
              if (_requiresEmail || widget.email.isEmpty) ...[
                Text(
                  'Email Address',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authState.isLoading,
                  decoration: const InputDecoration(
                    hintText: 'name@gmail.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Magic Link',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _linkController,
                enabled: !authState.isLoading,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Paste the complete email sign-in link',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: authState.isLoading ? null : _verifyPastedLink,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _verificationFailed
                              ? 'Try Verification Again'
                              : 'Verify Link & Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses FirebaseAuth's own email-link validation.
class FirebaseAuthLinkCheck {
  static bool isEmailLink(String link) {
    return FirebaseAuth.instance.isSignInWithEmailLink(link);
  }
}
