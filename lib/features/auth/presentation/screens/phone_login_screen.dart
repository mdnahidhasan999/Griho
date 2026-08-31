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

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phoneNumber = _completePhoneNumber.trim();

    if (phoneNumber.isEmpty) {
      return;
    }

    if (!PhoneNumberUtils.isValid(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid international phone number.'),
        ),
      );

      return;
    }

    await ref.read(authControllerProvider.notifier).sendOtp(phoneNumber);
  }

  // ============================================================
  // AUTH STATE
  // ============================================================

  void _handleAuthState(
    AuthControllerState? previous,
    AuthControllerState next,
  ) {
    if (!mounted) {
      return;
    }

    if (next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    }

    if (next.otpSent &&
        next.verificationId != null &&
        previous?.otpSent != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP sent successfully.')));

      final encodedInvitationId = widget.invitationId == null
          ? null
          : Uri.encodeComponent(widget.invitationId!);

      final location = encodedInvitationId == null
          ? RouteNames.otpVerification
          : '${RouteNames.otpVerification}'
                '?invitationId=$encodedInvitationId';

      context.push(location, extra: _completePhoneNumber);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthControllerState>(authControllerProvider, _handleAuthState);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Text(
                  'Welcome to Griho',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  widget.invitationId != null
                      ? 'Sign in with the phone number that received this invitation.'
                      : 'Enter your phone number to continue.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                IntlPhoneField(
                  controller: _phoneController,
                  initialCountryCode: 'BD',
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _sendOtp,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
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
