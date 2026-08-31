import 'package:flutter/material.dart';
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

    final result = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(
      smsCode: _otpController.text.trim(),
    );

    if (!mounted || result == null) {
      return;
    }

    // ==========================================================
    // INVITATION FLOW
    // ==========================================================
    //
    // If user came through:
    //
    // /i/ABC123
    //
    // then after OTP verification we MUST return to:
    //
    // /i/ABC123
    //
    // We must NOT send the user to onboarding/home first.
    // ==========================================================

    final invitationId = widget.invitationId?.trim();

    if (invitationId != null &&
        invitationId.isNotEmpty) {
      context.go(
        '${RouteNames.tenantInvitation}/'
            '${Uri.encodeComponent(invitationId)}',
      );

      return;
    }

    // ==========================================================
    // NORMAL AUTH FLOW
    // ==========================================================

    if (result.isNewUser) {
      context.go(
        RouteNames.onboarding,
      );

      return;
    }

    final user = result.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load your account information.',
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // ROLE BASED REDIRECT
    // ==========================================================

    switch (user.role) {
      case UserRole.owner:
        context.go(
          RouteNames.ownerHome,
        );
        return;

      case UserRole.manager:
        context.go(
          RouteNames.managerHome,
        );
        return;

      case UserRole.caretaker:
        context.go(
          RouteNames.caretakerHome,
        );
        return;

      case UserRole.tenant:
        context.go(
          RouteNames.tenantHome,
        );
        return;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(
      authControllerProvider,
    );

    ref.listen(
      authControllerProvider,
          (previous, next) {
        if (!mounted) {
          return;
        }

        if (next.errorMessage != null &&
            next.errorMessage !=
                previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                next.errorMessage!,
              ),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify OTP',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 40,
                ),

                // ==================================================
                // TITLE
                // ==================================================

                Text(
                  'Verify your phone',
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineMedium,
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Enter the verification code sent to '
                      '${widget.phoneNumber}.',
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodyMedium,
                ),

                // ==================================================
                // INVITATION NOTICE
                // ==================================================

                if (widget.invitationId != null &&
                    widget.invitationId!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height: 16,
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme
                          .of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mail_outline,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'After verification, '
                                'you will return to your tenant invitation.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(
                  height: 32,
                ),

                // ==================================================
                // OTP
                // ==================================================

                TextFormField(
                  controller: _otpController,
                  keyboardType:
                  TextInputType.number,
                  textInputAction:
                  TextInputAction.done,
                  maxLength: 6,
                  autofocus: true,
                  decoration:
                  const InputDecoration(
                    labelText: 'OTP',
                    hintText: 'Enter 6-digit code',
                    border:
                    OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) {
                    if (!authState.isLoading) {
                      _verifyOtp();
                    }
                  },
                  validator: (value) {
                    final otp =
                        value?.trim() ?? '';

                    if (otp.isEmpty) {
                      return 'Please enter the OTP.';
                    }

                    if (otp.length != 6) {
                      return 'OTP must be 6 digits.';
                    }

                    if (!RegExp(r'^\d{6}$')
                        .hasMatch(otp)) {
                      return 'OTP must contain only digits.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // VERIFY BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading
                        ? null
                        : _verifyOtp,
                    child: authState.isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Verify',
                    ),
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