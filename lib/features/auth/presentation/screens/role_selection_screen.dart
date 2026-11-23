// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/recipient_invitations_provider.dart';
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
    if (role == null || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      final profile =
          ref.read(currentUserProfileProvider).value ??
          await ref.read(currentUserProfileProvider.future);

      if (!mounted) return;

      if (profile == null) {
        GrihoFeedback.showError(
          context,
          'Your profile could not be found. Please complete your profile.',
        );
        context.go(RouteNames.onboarding);
        return;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';
      if (phoneNumber.isEmpty) {
        GrihoFeedback.showError(
          context,
          'Please complete your profile before selecting a role.',
        );
        context.go(RouteNames.onboarding);
        return;
      }

      await ref
          .read(userProfileRepositoryProvider)
          .saveInitialRole(profile.uid, role.name);

      if (!mounted) return;

      ref.invalidate(currentUserProfileProvider);

      switch (role) {
        case _SelectableRole.owner:
          GrihoFeedback.showSuccess(context, 'Owner role saved successfully.');
          context.go(RouteNames.ownerWelcome);

        case _SelectableRole.tenant:
          var pendingCount = 0;
          try {
            ref.invalidate(recipientInvitationsProvider);
            final invitations = await ref
                .read(recipientInvitationsProvider.future)
                .timeout(const Duration(seconds: 8));
            pendingCount = invitations
                .where(
                  (i) =>
                      i.status == TenantInvitationStatus.pending &&
                      !i.isExpired,
                )
                .length;
          } catch (_) {}

          if (!mounted) return;

          if (pendingCount > 0) {
            await showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                icon: const Icon(Iconsax.sms_notification),
                title: const Text('You have an invitation'),
                content: Text(
                  pendingCount == 1
                      ? 'A property owner has invited you. Review and accept it now.'
                      : 'Property owners have sent you $pendingCount invitations.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('View Invitations'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
          } else {
            GrihoFeedback.showSuccess(
              context,
              'Tenant role saved. Invitations will appear in Invites.',
            );
          }
          context.go(RouteNames.tenantInvitations);

        case _SelectableRole.manager:
          GrihoFeedback.showSuccess(
            context,
            'Manager role saved. Property access requires an owner invitation.',
          );
          context.go(RouteNames.managerHome);

        case _SelectableRole.caretaker:
          GrihoFeedback.showSuccess(
            context,
            'Caretaker role saved. Property access requires an owner invitation.',
          );
          context.go(RouteNames.caretakerHome);

        case _SelectableRole.electrician:
          GrihoFeedback.showSuccess(
            context,
            'Electrician role saved. Property access requires an owner invitation.',
          );
          context.go(RouteNames.electricianHome);
      }
    } catch (_) {
      if (!mounted) return;
      GrihoFeedback.showError(
        context,
        'Unable to save your selected role. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role'), centerTitle: false),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const GrihoLoadingView(message: 'Loading profile...'),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load your profile',
                subtitle: 'Please check your connection and try again.',
                actionLabel: 'Try Again',
                onAction: () => ref.invalidate(currentUserProfileProvider),
              ),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GrihoStatusState(
                    icon: Iconsax.user_remove,
                    title: 'Profile not available',
                    subtitle: 'Please complete your profile first to continue.',
                    actionLabel: 'Complete Profile',
                    onAction: () => context.go(RouteNames.onboarding),
                  ),
                ),
              );
            }

            final phoneNumber = profile.phoneNumber?.trim() ?? '';
            if (phoneNumber.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GrihoStatusState(
                    icon: Iconsax.user_edit,
                    title: 'Profile incomplete',
                    subtitle: 'Complete your profile before choosing a role.',
                    actionLabel: 'Complete Profile',
                    onAction: () => context.go(RouteNames.onboarding),
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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: GrihoLogo(size: 64),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Welcome, $name!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How would you like to use Griho? Choose a role to continue.',
                      style: theme.textTheme.bodyMedium?.copyWith(
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
                      icon: Iconsax.buildings_2,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.tenant,
                      title: 'Tenant',
                      subtitle: 'Access your rented home and monthly bills.',
                      icon: Iconsax.key,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.manager,
                      title: 'Property Manager',
                      subtitle:
                          'Manage property operations with owner authorization.',
                      icon: Iconsax.user_octagon,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.caretaker,
                      title: 'Caretaker',
                      subtitle:
                          'Handle building maintenance, visitor log & notices.',
                      icon: Iconsax.setting_2,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context: context,
                      role: _SelectableRole.electrician,
                      title: 'Electrician',
                      subtitle:
                          'Log meter readings and resolve electrical tickets.',
                      icon: Iconsax.flash_1,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecting a role does not grant access automatically. Staff and Tenant access require an owner invitation.',
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
              child: GrihoPrimaryButton(
                label: 'Continue',
                icon: Iconsax.arrow_right_3,
                isLoading: _isNavigating,
                onPressed: _selectedRole == null
                    ? null
                    : _continueWithSelectedRole,
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
              : () => setState(() => _selectedRole = role),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                  : theme.colorScheme.surfaceContainerLow,
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
                    size: 22,
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
