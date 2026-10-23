import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../providers/auth_provider.dart';

enum _SelectableRole { owner, tenant, manager, caretaker, electrician }

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  _SelectableRole? _selectedRole;

  bool _isNavigating = false;

  Future<void> _continueWithSelectedRole() async {
    final role = _selectedRole;

    if (role == null || _isNavigating) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    try {
      final profile = await ref.read(currentUserProfileProvider.future);

      if (!mounted) {
        return;
      }

      if (profile == null) {
        _showMessage(
          'Your profile could not be found. Please complete your profile.',
          isError: true,
        );

        context.go(RouteNames.onboarding);
        return;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';

      if (phoneNumber.isEmpty) {
        _showMessage(
          'Please complete your profile before selecting a role.',
          isError: true,
        );

        context.go(RouteNames.onboarding);
        return;
      }

      switch (role) {
        case _SelectableRole.owner:
          await ref
              .read(userProfileRepositoryProvider)
              .saveOwnerRole(profile.uid);

          if (!mounted) {
            return;
          }

          ref.invalidate(currentUserProfileProvider);

          _showMessage(
            'Owner role saved successfully.',
            isError: false,
          );

          context.go(RouteNames.ownerWelcome);
          break;

        case _SelectableRole.tenant:
          _showMessage(
            'Tenant access requires an invitation from the property owner.',
            isError: false,
          );

          context.go(RouteNames.tenantInvitations);
          break;

        case _SelectableRole.manager:
          _showMessage(
            'Manager access requires an invitation from the property owner.',
            isError: false,
          );
          break;

        case _SelectableRole.caretaker:
          _showMessage(
            'Caretaker access requires an invitation from the property owner.',
            isError: false,
          );
          break;

        case _SelectableRole.electrician:
          _showMessage(
            'Electrician access requires an invitation and authorization.',
            isError: false,
          );
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to continue. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme
              .of(context)
              .colorScheme
              .error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role'), centerTitle: false),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load your profile.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(currentUserProfileProvider);
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_off_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Your profile is not available. '
                            'Please complete your profile first.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          context.go(RouteNames.onboarding);
                        },
                        child: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final phoneNumber = profile.phoneNumber?.trim() ?? '';

            if (phoneNumber.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Complete your profile before choosing a role.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          context.go(RouteNames.onboarding);
                        },
                        child: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _buildRoleContent(
              context: context,
              theme: theme,
              name: profile.name,
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleContent({
    required BuildContext context,
    required ThemeData theme,
    required String name,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 42,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome, $name!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How would you like to use Griho? '
                          'Choose a role to continue.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.owner,
                      title: 'Property Owner',
                      subtitle:
                      'Manage your properties, units, tenants and bills.',
                      icon: Icons.home_work_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.tenant,
                      title: 'Tenant',
                      subtitle: 'Access your rented home and monthly bills.',
                      icon: Icons.key_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.manager,
                      title: 'Property Manager',
                      subtitle:
                      'Manage property operations with owner authorization.',
                      icon: Icons.manage_accounts_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.caretaker,
                      title: 'Caretaker',
                      subtitle: 'Help maintain and look after a property.',
                      icon: Icons.handyman_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.electrician,
                      title: 'Electrician',
                      subtitle:
                      'Receive authorized electrical maintenance work.',
                      icon: Icons.electrical_services_outlined,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecting a role does not grant access automatically. '
                          'Some roles require an invitation and approval.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selectedRole == null || _isNavigating
                      ? null
                      : _continueWithSelectedRole,
                  child: _isNavigating
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Continue'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required _SelectableRole role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedRole == role;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isNavigating
              ? null
              : () {
            setState(() {
              _selectedRole = role;
            });
          },
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
