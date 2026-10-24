import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../providers/current_tenant_pending_invitation_provider.dart';
import '../providers/tenant_invitation_provider.dart';

class TenantInvitationReceiveScreen extends ConsumerStatefulWidget {
  final String invitationId;

  const TenantInvitationReceiveScreen({
    super.key,
    required this.invitationId,
  });

  @override
  ConsumerState<TenantInvitationReceiveScreen> createState() =>
      _TenantInvitationReceiveScreenState();
}

class _TenantInvitationReceiveScreenState
    extends ConsumerState<TenantInvitationReceiveScreen> {
  TenantInvitation? _invitation;

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

  // ============================================================
  // LOAD INVITATION
  // ============================================================

  Future<void> _loadInvitation() async {
    final invitationId = widget.invitationId.trim();

    if (invitationId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Invitation ID is missing.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invitation = await ref.read(getTenantInvitationProvider)(
        invitationId,
      );

      if (!mounted) {
        return;
      }

      if (invitation == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
          'This invitation does not exist or is no longer available.';
        });

        return;
      }

      setState(() {
        _isLoading = false;
        _invitation = invitation;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> _acceptInvitation() async {
    final invitation = _invitation;

    if (invitation == null || _isAccepting || _isAccepted) {
      return;
    }

    if (!invitation.isPending || invitation.isExpired) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'This invitation is no longer valid or has expired.';
      });

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

      // Invalidate cached pending invitations
      ref.invalidate(currentTenantPendingInvitationProvider);

      setState(() {
        _isAccepting = false;
        _isAccepted = true;
        _errorMessage = null;
      });

      // Show confirmation dialog before entering home
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
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 18),
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
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
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

  // ============================================================
  // DECLINE INVITATION
  // ============================================================

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
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme
                    .of(dialogContext)
                    .colorScheme
                    .error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dialogTheme = Theme.of(dialogContext);

          return AlertDialog(
            title: const Text('Invitation Declined'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dialogTheme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    size: 48,
                    color: dialogTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'You have declined this tenancy invitation. The property owner will be informed.',
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
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Continue'),
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

  String _cleanError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }
    if (message.startsWith('Invalid argument(s): ')) {
      return message.substring(21);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Tenancy Invitation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Retrieving invitation details...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _invitation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to Load Invitation',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadInvitation,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final invitation = _invitation;
    if (invitation == null) {
      return const Center(
        child: Text('Invitation information is currently unavailable.'),
      );
    }

    if ((!invitation.isPending || invitation.isExpired) &&
        !_isAccepted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_busy_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Invitation Inactive or Expired',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This invitation link has expired or has already been processed by the property manager.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  context.go(RouteNames.tenantHome);
                },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final rentAmount = invitation.rentAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Greeting Banner
          Container(
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
                        ? Colors.green.withValues(alpha: 0.14)
                        : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAccepted
                        ? Icons.check_circle_rounded
                        : Icons.home_work_rounded,
                    size: 44,
                    color: _isAccepted
                        ? Colors.green.shade800
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAccepted
                      ? 'Tenancy Accepted'
                      : 'You\'re Invited to Join',
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

          // 2. Financial & Lease Highlight Card
          if (rentAmount > 0) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35),
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
                    child: const Icon(
                      Icons.payments_outlined,
                      size: 24,
                      color: Colors.white,
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
                          '৳ ${_formatAmount(rentAmount)} / month',
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

          // 3. Agreement Details Card
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lease Allocation Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: Icons.apartment_rounded,
                    title: 'Property',
                    value: invitation.propertyName ??
                        'Property details unlisted',
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.door_front_door_outlined,
                    title: 'Assigned Unit',
                    value: _formatUnit(invitation),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    title: 'Invited Phone Number',
                    value: invitation.phone?.trim().isNotEmpty == true
                        ? invitation.phone!.trim()
                        : 'Not provided',
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    title: 'Invitation Valid Until',
                    value: _formatDate(invitation.expiresAt),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 4. Information Transparency Note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
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
                    color: theme.colorScheme.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: theme.colorScheme.error, size: 20),
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

          // 5. Action Buttons
          if (!_isAccepted) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isAccepting ? null : _acceptInvitation,
                icon: _isAccepting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isAccepting ? 'Connecting...' : 'Accept Tenancy Invitation',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isAccepting ? null : _rejectInvitation,
                child: const Text(
                  'Decline Invitation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else
            ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    context.go(RouteNames.tenantHome);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    'Proceed to Tenant Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  String _formatUnit(TenantInvitation invitation) {
    final unitName = invitation.unitName?.trim();
    final unitNumber = invitation.unitNumber?.trim();

    if (unitName != null &&
        unitName.isNotEmpty &&
        unitNumber != null &&
        unitNumber.isNotEmpty) {
      return '$unitName (Unit $unitNumber)';
    }

    if (unitName != null && unitName.isNotEmpty) {
      return unitName;
    }

    if (unitNumber != null && unitNumber.isNotEmpty) {
      return 'Unit $unitNumber';
    }

    return 'Unit unassigned';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year at $hour:$minute $period';
  }

  String _formatAmount(num? amount) {
    if (amount == null) {
      return '0.00';
    }
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }
}

// ============================================================================
// DETAIL ROW
// ============================================================================

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
                alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
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
