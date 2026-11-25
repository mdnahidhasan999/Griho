// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../providers/current_tenant_pending_invitation_provider.dart';
import '../providers/recipient_invitations_provider.dart';
import '../providers/tenant_dashboard_provider.dart';
import '../providers/tenant_invitation_provider.dart';
import '../widgets/tenant_ui_helpers.dart';

class TenantInvitationReceiveScreen extends ConsumerStatefulWidget {
  final String invitationToken;

  const TenantInvitationReceiveScreen({
    super.key,
    required this.invitationToken,
  });

  @override
  ConsumerState<TenantInvitationReceiveScreen> createState() =>
      _TenantInvitationReceiveScreenState();
}

class _TenantInvitationReceiveScreenState
    extends ConsumerState<TenantInvitationReceiveScreen> {
  TenantInvitation? _invitation;

  List<String> _houseRules = const [];
  String _ownerName = '';
  bool _agreedToRules = false;

  bool _isLoading = true;
  bool _isAccepting = false;
  bool _isAccepted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvitation();
    });
  }

  Future<void> _loadInvitation() async {
    final token = widget.invitationToken.trim();
    if (!mounted) {
      return;
    }

    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invitation token is missing.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _agreedToRules = false;
    });

    try {
      final invitation = await ref.read(getInvitationByTokenProvider)(token);

      if (!mounted) {
        return;
      }

      if (invitation == null) {
        setState(() {
          _isLoading = false;
          _invitation = null;
          _houseRules = const [];
          _ownerName = '';
          _errorMessage =
              'This invitation does not exist, has expired, or is no longer available.';
        });
        return;
      }

      List<String> loadedRules = const [];
      String loadedOwnerName = '';

      final ownerId = invitation.ownerId.trim();
      if (ownerId.isNotEmpty) {
        try {
          final rulesDoc = await FirebaseFirestore.instance
              .collection('house_rules')
              .doc(ownerId)
              .get();
          final rawData = rulesDoc.data();
          loadedOwnerName = (rawData?['ownerName'] ?? '').toString().trim();
          final rawRules = rawData?['rules'];
          if (rawRules is List) {
            loadedRules = rawRules
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {
          // Keep invitation accessible even if house rules doc is unreadable or absent.
          loadedRules = const [];
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _invitation = invitation;
        _houseRules = loadedRules;
        _ownerName = loadedOwnerName;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _invitation = null;
        _houseRules = const [];
        _ownerName = '';
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _acceptInvitation() async {
    final invitation = _invitation;
    if (invitation == null || _isAccepting || _isAccepted) {
      return;
    }

    if (!invitation.isPending || invitation.isExpired) {
      if (mounted) {
        setState(() {
          _errorMessage = 'This invitation is no longer valid or has expired.';
        });
      }
      return;
    }

    if (_houseRules.isNotEmpty && !_agreedToRules) {
      GrihoFeedback.showWarning(
        context,
        'অনুগ্রহ করে আগে মালিকের বাসা ভাড়ার নিয়মাবলীতে সম্মতি দিন।',
      );
      return;
    }

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(acceptTenantInvitationProvider)(invitation.id);

      if (!mounted) {
        return;
      }

      ref.invalidate(recipientInvitationsProvider);
      ref.invalidate(currentTenantProvider);
      ref.invalidate(tenantDashboardProvider);

      setState(() {
        _isAccepting = false;
        _isAccepted = true;
        _errorMessage = null;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dialogTheme = Theme.of(dialogContext);

          return AlertDialog(
            title: const Text('Invitation Accepted'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GrihoColors.emerald.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.tick_circle,
                    size: 44,
                    color: GrihoColors.emerald,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Griho account is now officially connected to this tenancy agreement.',
                  textAlign: TextAlign.center,
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    color: dialogTheme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Go to Home Dashboard'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      context.go(RouteNames.tenantHome);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAccepting = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _rejectInvitation() async {
    final invitation = _invitation;
    if (invitation == null || _isAccepting || _isAccepted) {
      return;
    }

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Decline Tenancy Invitation?'),
          content: const Text(
            'Are you sure you want to decline this invitation? You will not be linked to this unit unless the property owner sends a new invitation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true || !mounted) {
      return;
    }

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(cancelTenantInvitationProvider)(invitation.id);

      if (!mounted) {
        return;
      }

      ref.invalidate(currentTenantPendingInvitationProvider);

      setState(() {
        _isAccepting = false;
        _errorMessage = null;
      });

      GrihoFeedback.showWarning(context, 'You have declined this invitation.');
      context.go(RouteNames.tenantHome);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAccepting = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(
      RegExp(r'^(Exception: |Invalid argument\(s\): |Bad state: )'),
      '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Tenancy Invitation')),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const GrihoLoadingView(message: 'Retrieving invitation...');
    }

    if (_errorMessage != null && _invitation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.warning_2,
            title: 'Unable to Load Invitation',
            subtitle: _errorMessage!,
            actionLabel: 'Try Again',
            onAction: _loadInvitation,
          ),
        ),
      );
    }

    final invitation = _invitation;
    if (invitation == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.sms,
            title: 'Invitation Unavailable',
            subtitle: 'Invitation information is currently unavailable.',
          ),
        ),
      );
    }

    if ((!invitation.isPending || invitation.isExpired) && !_isAccepted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.calendar_remove,
            title: 'Invitation Inactive or Expired',
            subtitle:
                'This invitation link has expired or has already been processed by the property manager.',
            actionLabel: 'Return to Home',
            onAction: () => context.go(RouteNames.tenantHome),
          ),
        ),
      );
    }

    final rentAmount = invitation.rentAmount;
    final canAccept = !_isAccepting && (_houseRules.isEmpty || _agreedToRules);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isAccepted
                        ? GrihoColors.emerald.withValues(alpha: 0.14)
                        : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAccepted ? Iconsax.tick_circle : Iconsax.buildings_2,
                    size: 40,
                    color: _isAccepted
                        ? GrihoColors.emerald
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAccepted ? 'Tenancy Accepted' : 'You\'re Invited to Join',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isAccepted
                      ? 'Your Griho account is linked to this property space.'
                      : 'A property owner has invited you to activate your official tenancy.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (rentAmount > 0) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Iconsax.wallet_3,
                      size: 22,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agreed Monthly Rent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '৳ ${formatTenantAmount(rentAmount)} / month',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          GrihoSectionCard(
            title: 'Lease Allocation Details',
            icon: Iconsax.document_text,
            children: [
              _DetailRow(
                icon: Iconsax.buildings_2,
                title: 'Property',
                value: invitation.propertyName ?? 'Property details unlisted',
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Iconsax.home_2,
                title: 'Assigned Unit',
                value: formatInvitationUnit(invitation),
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Iconsax.call,
                title: 'Invited Phone Number',
                value: invitation.phone?.trim().isNotEmpty == true
                    ? invitation.phone!.trim()
                    : 'Not provided',
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Iconsax.clock,
                title: 'Invitation Valid Until',
                value: formatTenantDate(
                  invitation.expiresAt,
                  includeTime: true,
                ),
              ),
            ],
          ),
          if (_houseRules.isNotEmpty) ...[
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: 'House Rules & Policies (${_houseRules.length})',
              subtitle: _ownerName.isNotEmpty
                  ? '$_ownerName-এর নির্ধারিত বাসা ভাড়ার নিয়মাবলী'
                  : 'মালিকের নির্ধারিত বাসা ভাড়ার নিয়মাবলী',
              icon: Iconsax.document_text_1,
              children: [
                for (var i = 0; i < _houseRules.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GrihoColors.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: GrihoColors.emerald,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _houseRules[i],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != _houseRules.length - 1) const Divider(height: 1),
                ],
                if (!_isAccepted) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _agreedToRules
                          ? GrihoColors.emerald.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _agreedToRules
                            ? GrihoColors.emerald
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _agreedToRules,
                      activeColor: GrihoColors.emerald,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      title: Text(
                        'আমি মালিকের নির্ধারিত সকল বাসা ভাড়ার নিয়মাবলী পড়েছি এবং মেনে চলতে সম্মত আছি।',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      onChanged: _isAccepting
                          ? null
                          : (val) =>
                                setState(() => _agreedToRules = val ?? false),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Iconsax.shield_tick,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isAccepted
                        ? 'Your tenancy is now synchronized. Upcoming utility invoices and rental statements will appear on your home feed.'
                        : 'By accepting, this tenancy will be formally connected to your profile, enabling direct invoice tracking and utility payment history.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null && !_isAccepted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.warning_2,
                    color: theme.colorScheme.error,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (!_isAccepted) ...[
            GrihoPrimaryButton(
              label: _isAccepting
                  ? 'Connecting...'
                  : 'Accept Tenancy Invitation',
              icon: Iconsax.tick_circle,
              isLoading: _isAccepting,
              onPressed: canAccept ? _acceptInvitation : null,
            ),
            const SizedBox(height: 12),
            GrihoSecondaryButton(
              label: 'Decline Invitation',
              onPressed: _isAccepting ? null : _rejectInvitation,
            ),
          ] else
            GrihoPrimaryButton(
              label: 'Proceed to Tenant Dashboard',
              icon: Iconsax.arrow_right_3,
              onPressed: () => context.go(RouteNames.tenantHome),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
