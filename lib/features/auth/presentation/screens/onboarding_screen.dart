import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';
import '../providers/auth_controller.dart';

// ================================================================
// ONBOARDING SCREEN
// ================================================================

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  RegistrationIntent? _selectedIntent;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ============================================================
  // CONTINUE ACTION
  // ============================================================

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final intent = _selectedIntent;

    if (intent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose whether you are an Owner or a Tenant.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref
        .read(authControllerProvider.notifier)
        .register(intent: intent, name: _nameController.text.trim());

    if (!mounted || result == null) {
      return;
    }

    final user = result.user;

    // ----------------------------------------------------------
    // OWNER REDIRECT
    // ----------------------------------------------------------
    if (user.role == UserRole.owner) {
      context.go(RouteNames.ownerHome);
      return;
    }

    // ----------------------------------------------------------
    // TENANT REDIRECT
    // ----------------------------------------------------------
    if (user.role == UserRole.tenant) {
      final invitationId = result.invitationId;

      if (invitationId != null && invitationId.trim().isNotEmpty) {
        context.go(RouteNames.tenantInvitationPath(invitationId));
        return;
      }

      context.go(RouteNames.tenantHome);
      return;
    }

    // ----------------------------------------------------------
    // OTHER ROLES
    // ----------------------------------------------------------
    switch (user.role) {
      case UserRole.manager:
        context.go(RouteNames.managerHome);
        return;
      case UserRole.caretaker:
        context.go(RouteNames.caretakerHome);
        return;
      case UserRole.owner:
      case UserRole.tenant:
        return;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
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
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Profile Setup',
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
                // ============================================================
                // ১. ওয়েলকাম হেডার
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.waving_hand_rounded,
                    size: 28,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Griho',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete your profile setup to personalize your property and tenancy experience.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 28),

                // ============================================================
                // ২. পুরো নাম ইনপুট
                // ============================================================
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
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'e.g. Md Nahid Hasan',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) {
                      return 'Please enter your name.';
                    }
                    if (name.length < 2) {
                      return 'Name must be at least 2 characters.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ============================================================
                // ৩. একাউন্ট টাইপ নির্বাচন
                // ============================================================
                Text(
                  'How will you use Griho?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the role that fits your current requirements.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),

                // Property Owner Card
                _RoleSelectionCard(
                  title: 'Property Owner',
                  description:
                      'Manage properties, list units, track utility bills and monitor tenant rents.',
                  icon: Icons.apartment_rounded,
                  selected: _selectedIntent == RegistrationIntent.owner,
                  onTap: authState.isLoading
                      ? () {}
                      : () {
                          setState(() {
                            _selectedIntent = RegistrationIntent.owner;
                          });
                        },
                ),

                const SizedBox(height: 12),

                // Tenant Card
                _RoleSelectionCard(
                  title: 'Tenant (ভাড়াটিয়া)',
                  description:
                      'View monthly rent, electricity & water bills, and manage ongoing tenancy.',
                  icon: Icons.key_rounded,
                  selected: _selectedIntent == RegistrationIntent.tenant,
                  onTap: authState.isLoading
                      ? () {}
                      : () {
                          setState(() {
                            _selectedIntent = RegistrationIntent.tenant;
                          });
                        },
                ),

                const SizedBox(height: 36),

                // ============================================================
                // ৪. সাবমিট বাটন
                // ============================================================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _continue,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Your verified phone number will be securely linked to this account.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
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

// ============================================================================
// ROLE SELECTION CARD WIDGET
// ============================================================================

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
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
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
