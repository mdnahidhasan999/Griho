import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../providers/auth_controller.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  final String? invitationId;

  const PhoneLoginScreen({super.key, this.invitationId});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  String _completePhoneNumber = '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // আন্তর্জাতিক E.164 স্যানিটাইজেশন
    final cleanPhone = PhoneNumberUtils.clean(_completePhoneNumber);

    if (!PhoneNumberUtils.isValid(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid international phone number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).sendOtp(cleanPhone);
  }

  void _handleAuthState(
    AuthControllerState? previous,
    AuthControllerState next,
  ) {
    if (!mounted) {
      return;
    }

    if (next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (next.otpSent &&
        next.verificationId != null &&
        previous?.otpSent != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final cleanPhone = PhoneNumberUtils.clean(_completePhoneNumber);

      final encodedInvitationId = widget.invitationId == null
          ? null
          : Uri.encodeComponent(widget.invitationId!);

      final location = encodedInvitationId == null
          ? RouteNames.otpVerification
          : '${RouteNames.otpVerification}?invitationId=$encodedInvitationId';

      context.push(location, extra: cleanPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthControllerState>(authControllerProvider, _handleAuthState);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ১. ব্র্যান্ডিং আইকন
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    size: 32,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 24),

                // ২. শিরোনাম
                Text(
                  'Welcome to Griho',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter your mobile number to receive a secure one-time verification code.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),

                // ৩. ইনভাইটেশন নোটিশ (যদি লিংক থেকে আসে)
                if (widget.invitationId != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mail_lock_outlined,
                          size: 20,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please sign in with the specific phone number where your tenancy invitation was received.',
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

                const SizedBox(height: 32),

                // ৪. কান্ট্রি কোড সহ ফোন নম্বর ফিল্ড
                Text(
                  'Phone Number',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                IntlPhoneField(
                  controller: _phoneController,
                  initialCountryCode: 'BD',
                  disableLengthCheck: false,
                  enabled: !authState.isLoading,
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                  validator: (phone) {
                    if (phone == null || phone.number.trim().isEmpty) {
                      return 'Please enter your phone number.';
                    }
                    if (!PhoneNumberUtils.isValid(phone.completeNumber)) {
                      return 'Please enter a valid international phone number.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // ৫. কনটিনিউ বাটন
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _sendOtp,
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
                            'Send Verification Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ৬. সিকিউরিটি নোট
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Standard operator SMS rates may apply.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
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
