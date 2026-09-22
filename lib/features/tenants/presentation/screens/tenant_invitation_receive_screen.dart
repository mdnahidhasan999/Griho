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
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Invitation ID is missing.';
      });

      return;
    }

    try {
      final invitation = await ref.read(getTenantInvitationProvider)(
        invitationId,
      );

      if (!mounted) return;

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
      if (!mounted) return;

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

    if (!invitation.isValid) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'This invitation is no longer valid.';
      });

      return;
    }

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    debugPrint('');
    debugPrint('════════════════════════════════════════════');
    debugPrint('🔐 ACCEPT INVITATION STARTED');
    debugPrint('════════════════════════════════════════════');
    debugPrint('Invitation ID : ${invitation.id}');
    debugPrint('Tenant ID     : ${invitation.tenantId}');
    debugPrint('Property ID   : ${invitation.propertyId}');
    debugPrint('Unit ID       : ${invitation.unitId}');
    debugPrint('Phone         : ${invitation.phone}');
    debugPrint('Rent Amount   : ${invitation.rentAmount}');
    debugPrint('Owner ID      : ${invitation.ownerId}');
    debugPrint('════════════════════════════════════════════');
    debugPrint('');

    try {
      debugPrint(
        '➡️ STEP 1: Calling acceptTenantInvitationProvider...',
      );

      await ref.read(acceptTenantInvitationProvider)(
        invitation.id,
      );

      debugPrint(
        '✅ STEP 1 SUCCESS: Invitation accepted.',
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // IMPORTANT:
      // The invitation status has changed from PENDING to
      // ACCEPTED in Firestore.
      //
      // The TenantHomeInvitationGateScreen watches
      // currentTenantPendingInvitationProvider.
      //
      // Invalidate it here so it does not keep using the old
      // cached pending invitation.
      // --------------------------------------------------------

      ref.invalidate(
        currentTenantPendingInvitationProvider,
      );

      debugPrint(
        '✅ PENDING INVITATION PROVIDER INVALIDATED.',
      );

      // --------------------------------------------------------
      // UPDATE LOCAL UI STATE
      // --------------------------------------------------------

      setState(() {
        _isAccepting = false;
        _isAccepted = true;
        _errorMessage = null;
      });

      debugPrint(
        '✅ ACCEPT UI: Loading state stopped.',
      );

      debugPrint(
        '✅ ACCEPT UI: Invitation marked as locally accepted.',
      );

      // --------------------------------------------------------
      // SUCCESS DIALOG
      // --------------------------------------------------------

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              size: 56,
            ),
            title: const Text(
              'Invitation Accepted',
            ),
            content: const Text(
              'Your tenant account has been successfully connected to this tenancy.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // GO TO TENANT HOME
      // --------------------------------------------------------

      debugPrint(
        '➡️ NAVIGATING TO TENANT HOME...',
      );

      context.go(
        RouteNames.tenantHome,
      );
    } catch (error, stackTrace) {
      debugPrint('');
      debugPrint('❌❌❌ ACCEPT INVITATION FAILED ❌❌❌');
      debugPrint('Invitation ID : ${invitation.id}');
      debugPrint('Error Type    : ${error.runtimeType}');
      debugPrint('Error         : $error');
      debugPrint('');
      debugPrint('STACK TRACE:');
      debugPrint(stackTrace.toString());
      debugPrint('════════════════════════════════════════════');
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _isAccepting = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  // ============================================================
  // CANCEL / REJECT
  // ============================================================

  Future<void> _rejectInvitation() async {
    final invitation = _invitation;

    if (invitation == null || _isAccepting || _isAccepted) {
      return;
    }

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Decline Invitation?',
          ),
          content: const Text(
            'Are you sure you want to decline this tenancy invitation?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Decline',
              ),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(cancelTenantInvitationProvider)(
        invitation.id,
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // IMPORTANT:
      // Remove cached pending invitation after rejection.
      // --------------------------------------------------------

      ref.invalidate(
        currentTenantPendingInvitationProvider,
      );

      debugPrint(
        '✅ PENDING INVITATION PROVIDER INVALIDATED AFTER REJECTION.',
      );

      // --------------------------------------------------------
      // STOP LOADING
      // --------------------------------------------------------

      setState(() {
        _isAccepting = false;
        _errorMessage = null;
      });

      // --------------------------------------------------------
      // SUCCESS DIALOG
      // --------------------------------------------------------

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.cancel_outlined,
              size: 56,
            ),
            title: const Text(
              'Invitation Declined',
            ),
            content: const Text(
              'You have declined this tenancy invitation.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      context.go(
        RouteNames.tenantHome,
      );
    } catch (error, stackTrace) {
      debugPrint('');
      debugPrint('❌❌❌ REJECT INVITATION FAILED ❌❌❌');
      debugPrint('Invitation ID : ${invitation.id}');
      debugPrint('Error Type    : ${error.runtimeType}');
      debugPrint('Error         : $error');
      debugPrint('STACK TRACE:');
      debugPrint(stackTrace.toString());
      debugPrint('════════════════════════════════════════════');
      debugPrint('');

      if (!mounted) return;

      setState(() {
        _isAccepting = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tenant Invitation',
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading invitation...',
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_errorMessage != null && _invitation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _loadInvitation,
                child: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final invitation = _invitation;

    if (invitation == null) {
      return const Center(
        child: Text(
          'Invitation unavailable.',
        ),
      );
    }

    // ----------------------------------------------------------
    // EXPIRED / INVALID
    // ----------------------------------------------------------

    if (!invitation.isValid && !_isAccepted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                'This invitation is no longer valid.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The invitation may have expired, been accepted, or been cancelled.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // NORMAL INVITATION
    // ----------------------------------------------------------

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ====================================================
          // HEADER
          // ====================================================

          Center(
            child: Column(
              children: [
                Icon(
                  _isAccepted
                      ? Icons.check_circle_outline
                      : Icons.home_work_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  _isAccepted
                      ? 'Invitation Accepted'
                      : 'You Have a Tenant Invitation',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _isAccepted
                      ? 'Your Griho account is now connected to this tenancy.'
                      : 'A property owner has invited you to join a tenancy.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ====================================================
          // INVITATION DETAILS
          // ====================================================

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.home_outlined,
                    title: 'Property',
                    value:
                    invitation.propertyName ??
                        'Property information unavailable',
                  ),

                  const Divider(
                    height: 28,
                  ),

                  _DetailRow(
                    icon: Icons.door_front_door_outlined,
                    title: 'Unit',
                    value: _formatUnit(invitation),
                  ),

                  const Divider(
                    height: 28,
                  ),

                  _DetailRow(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: invitation.phone,
                  ),

                  const Divider(
                    height: 28,
                  ),

                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Expires',
                    value: _formatDate(
                      invitation.expiresAt,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ====================================================
          // SUCCESS MESSAGE
          // ====================================================

          if (_isAccepted) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invitation accepted successfully. '
                            'Your tenant account is now connected to this tenancy.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ====================================================
          // WARNING / ERROR
          // ====================================================

          if (_errorMessage != null && !_isAccepted) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ====================================================
          // ACCEPT
          // ====================================================

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
              _isAccepting || _isAccepted
                  ? null
                  : _acceptInvitation,
              child: _isAccepting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : _isAccepted
                  ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Invitation Accepted',
                  ),
                ],
              )
                  : const Text(
                'Accept Invitation',
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ====================================================
          // DECLINE
          // ====================================================

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
              _isAccepting || _isAccepted
                  ? null
                  : _rejectInvitation,
              child: const Text(
                'Decline',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ====================================================
          // INFO
          // ====================================================

          Text(
            _isAccepted
                ? 'Your Griho account has been connected to this tenancy.'
                : 'By accepting this invitation, your Griho account will be connected to this tenancy.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UNIT DISPLAY
  // ============================================================

  String _formatUnit(TenantInvitation invitation) {
    final unitName = invitation.unitName;
    final unitNumber = invitation.unitNumber;

    if (unitName != null &&
        unitName.isNotEmpty &&
        unitNumber != null &&
        unitNumber.isNotEmpty) {
      return '$unitName ($unitNumber)';
    }

    if (unitName != null && unitName.isNotEmpty) {
      return unitName;
    }

    if (unitNumber != null && unitNumber.isNotEmpty) {
      return unitNumber;
    }

    return 'Unit information unavailable';
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour % 12 == 0
        ? 12
        : date.hour % 12;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12
        ? 'PM'
        : 'AM';

    return '$day/$month/$year, '
        '$hour:$minute $period';
  }
}

// ================================================================
// DETAIL ROW
// ================================================================

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}