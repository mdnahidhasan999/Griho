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

  // ==============================================================
  // CONTINUE
  // ==============================================================

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final intent = _selectedIntent;

    if (intent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account type.')),
      );

      return;
    }

    final controller = ref.read(authControllerProvider.notifier);

    final user = await controller.register(
      intent: intent,
      name: _nameController.text.trim(),
    );

    if (!mounted || user == null) {
      return;
    }

    // ==========================================================
    // OWNER
    // ==========================================================

    if (user.role == UserRole.owner) {
      context.go(RouteNames.ownerHome);

      return;
    }

    // ==========================================================
    // TENANT
    // ==========================================================

    if (user.role == UserRole.tenant) {
      final invitationId = ref.read(authControllerProvider).invitationId;

      // --------------------------------------------------------
      // PENDING INVITATION EXISTS
      // --------------------------------------------------------

      if (invitationId != null && invitationId.trim().isNotEmpty) {
        debugPrint(
          'ONBOARDING: '
          'going to tenant invitation screen. '
          'Invitation ID: $invitationId',
        );

        context.go('${RouteNames.tenantAccountLink}/$invitationId');

        return;
      }

      // --------------------------------------------------------
      // NO INVITATION
      // --------------------------------------------------------

      debugPrint(
        'ONBOARDING: '
        'no tenant invitation found.',
      );

      context.go(RouteNames.tenantHome);

      return;
    }

    // ==========================================================
    // OTHER ROLES
    // ==========================================================

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

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create your Griho account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ==================================================
                // TITLE
                // ==================================================
                Text(
                  'Welcome to Griho',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  'Tell us a little about yourself to get started.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                // ==================================================
                // NAME
                // ==================================================
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
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

                const SizedBox(height: 32),

                // ==================================================
                // ACCOUNT TYPE
                // ==================================================
                Text(
                  'How will you use Griho?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 12),

                // ==================================================
                // OWNER
                // ==================================================
                _AccountTypeCard(
                  title: 'Property Owner',
                  description: 'Manage your properties, tenants and bills.',
                  icon: Icons.home_work_outlined,
                  selected: _selectedIntent == RegistrationIntent.owner,
                  onTap: () {
                    setState(() {
                      _selectedIntent = RegistrationIntent.owner;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // TENANT
                // ==================================================
                _AccountTypeCard(
                  title: 'Tenant',
                  description: 'Manage your rent, bills and payments.',
                  icon: Icons.person_outline,
                  selected: _selectedIntent == RegistrationIntent.tenant,
                  onTap: () {
                    setState(() {
                      _selectedIntent = RegistrationIntent.tenant;
                    });
                  },
                ),

                const SizedBox(height: 32),

                // ==================================================
                // CONTINUE
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _continue,
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

// ================================================================
// ACCOUNT TYPE CARD
// ================================================================

class _AccountTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
