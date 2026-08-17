import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../app/router/route_names.dart';
import '../providers/auth_controller.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({
    super.key,
  });

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

    final controller = ref.read(authControllerProvider.notifier);

    await controller.sendOtp(
      _completePhoneNumber,
    );

    if (!mounted) {
      return;
    }

    final authState = ref.read(authControllerProvider);

    if (authState.otpSent &&
        authState.verificationId != null) {
      context.push(
        RouteNames.otpVerification,
        extra: _completePhoneNumber,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(
      authControllerProvider,
          (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
            ),
          );
        }

        if (next.otpSent && previous?.otpSent != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully.'),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
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
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter your phone number to continue.',
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodyMedium,
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
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
