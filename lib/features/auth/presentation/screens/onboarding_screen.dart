import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';
import '../providers/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _completePhoneNumber = '';
  RegistrationIntent? _selectedIntent;

  @override
  void initState() {
    super.initState();
    // ফায়ারবেস থেকে ভেরিফাইড ইমেইলটি স্বয়ংক্রিয়ভাবে নিয়ে নিচ্ছে
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail != null) {
      _emailController.text = userEmail;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedIntent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose whether you are an Owner or a Tenant.'),
        ),
      );
      return;
    }

    final cleanPhone = PhoneNumberUtils.clean(_completePhoneNumber);
    if (!PhoneNumberUtils.isValid(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid permanent phone number.'),
        ),
      );
      return;
    }

    final result = await ref
        .read(authControllerProvider.notifier)
        .registerWithEmailAndPhone(
          intent: _selectedIntent!,
          name: _nameController.text.trim(),
          phoneNumber: cleanPhone,
        );

    if (!mounted || result == null) return;

    final user = result.user;
    if (user.role == UserRole.owner) {
      context.go(RouteNames.ownerHome);
    } else if (user.role == UserRole.tenant) {
      context.go(RouteNames.tenantHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Almost There!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please provide your full name and a permanent phone number to finish your account setup.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Full Name',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  enabled: !authState.isLoading,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Md Nahid Hasan',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  validator: (v) => v?.trim().isEmpty == true
                      ? 'Please enter your name.'
                      : null,
                ),
                const SizedBox(height: 20),

                Text(
                  'Email Address (Verified)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Permanent Phone Number',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                IntlPhoneField(
                  initialCountryCode: 'BD',
                  enabled: !authState.isLoading,
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  onChanged: (phone) =>
                      _completePhoneNumber = phone.completeNumber,
                  validator: (phone) =>
                      (phone == null || phone.number.trim().isEmpty)
                      ? 'Permanent phone number is required.'
                      : null,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This phone number cannot be changed later.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                Text(
                  'How will you use Griho?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _RoleSelectionCard(
                  title: 'Property Owner',
                  description: 'Manage properties, units, and track rents.',
                  icon: Icons.apartment_rounded,
                  selected: _selectedIntent == RegistrationIntent.owner,
                  onTap: () => setState(
                    () => _selectedIntent = RegistrationIntent.owner,
                  ),
                ),
                const SizedBox(height: 12),
                _RoleSelectionCard(
                  title: 'Tenant (ভাড়াটিয়া)',
                  description:
                      'View monthly rent, utility bills, and tenancy status.',
                  icon: Icons.key_rounded,
                  selected: _selectedIntent == RegistrationIntent.tenant,
                  onTap: () => setState(
                    () => _selectedIntent = RegistrationIntent.tenant,
                  ),
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _continue,
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
                        : const Text(
                            'Complete & Continue',
                            style: TextStyle(
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
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
