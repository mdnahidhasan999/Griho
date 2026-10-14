import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? invitationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.invitationId,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).verifyOtp(
      smsCode: _otpController.text.trim(),
    );

    if (!mounted || result == null) {
      return;
    }

    // ----------------------------------------------------------
    // INVITATION FLOW
    // ----------------------------------------------------------
    final invitationId = widget.invitationId?.trim();
    if (invitationId != null && invitationId.isNotEmpty) {
      context.go(
        '${RouteNames.tenantInvitation}/${Uri.encodeComponent(invitationId)}',
      );
      return;
    }

    // ----------------------------------------------------------
    // NORMAL ONBOARDING FLOW
    // ----------------------------------------------------------
    if (result.isNewUser) {
      context.go(RouteNames.onboarding);
      return;
    }

    final user = result.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load your account information.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ----------------------------------------------------------
    // ROLE-BASED DASHBOARD REDIRECT
    // ----------------------------------------------------------
    switch (user.role) {
      case UserRole.owner:
        context.go(RouteNames.ownerHome);
        return;
      case UserRole.manager:
        context.go(RouteNames.managerHome);
        return;
      case UserRole.caretaker:
        context.go(RouteNames.caretakerHome);
        return;
      case UserRole.tenant:
        context.go(RouteNames.tenantHome);
        return;
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp() async {
    final phoneNumber = widget.phoneNumber.trim();
    if (phoneNumber.isEmpty) {
      return;
    }

    _otpController.clear();
    await ref.read(authControllerProvider.notifier).sendOtp(phoneNumber);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code resent successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen(
      authControllerProvider,
          (previous, next) {
        if (!mounted) {
          return;
        }

        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Icon Badge
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

                // 2. Titles
                Text(
                  'Verify Your Phone',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'We sent a 6-digit confirmation code to:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Destination Phone Chip with Change Action
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.phoneNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: authState.isLoading
                            ? null
                            : () {
                          context.pop();
                        },
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Invitation Notice Banner (Conditional)
                if (widget.invitationId != null &&
                    widget.invitationId!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(
                          alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Once verified, you will proceed directly to review and accept your tenancy invitation.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // 5. Stylized 6-Digit OTP Field
                Text(
                  'Enter Verification Code',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  enabled: !authState.isLoading,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 20,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.outlineVariant,
                      letterSpacing: 20,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (!authState.isLoading) {
                      _verifyOtp();
                    }
                  },
                  validator: (value) {
                    final otp = value?.trim() ?? '';
                    if (otp.isEmpty) {
                      return 'Please enter the 6-digit code.';
                    }
                    if (otp.length != 6) {
                      return 'Code must be exactly 6 digits.';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                      return 'Code must contain only digits.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // 6. Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _verifyOtp,
                    child: authState.isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 7. Resend Code Row
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Didn\'t receive the code? ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: authState.isLoading ? null : _resendOtp,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
