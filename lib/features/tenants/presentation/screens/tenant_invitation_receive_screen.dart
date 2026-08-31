import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../../app/router/route_names.dart';

import '../../domain/entities/tenant_invitation.dart';
import '../providers/tenant_invitation_provider.dart';

class TenantInvitationReceiveScreen extends ConsumerStatefulWidget {
  final String invitationId;

  const TenantInvitationReceiveScreen({super.key, required this.invitationId});

  @override
  ConsumerState<TenantInvitationReceiveScreen> createState() =>
      _TenantInvitationReceiveScreenState();
}

class _TenantInvitationReceiveScreenState
    extends ConsumerState<TenantInvitationReceiveScreen> {
  TenantInvitation? _invitation;

  bool _isLoading = false;
  bool _isAccepting = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  void _initialize() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });

      return;
    }

    _loadInvitation();
  }

  // ============================================================
  // LOAD INVITATION
  // ============================================================

  Future<void> _loadInvitation() async {
    if (!mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(tenantInvitationRepositoryProvider);

      final invitation = await repository.getInvitationById(
        widget.invitationId,
      );

      if (!mounted) {
        return;
      }

      if (invitation == null) {
        setState(() {
          _isLoading = false;
          _error = 'This invitation does not exist or has expired.';
        });

        return;
      }

      if (invitation.status != TenantInvitationStatus.pending) {
        setState(() {
          _isLoading = false;
          _error = 'This invitation has already been used.';
        });

        return;
      }

      if (invitation.isExpired) {
        setState(() {
          _isLoading = false;
          _error = 'This invitation has expired.';
        });

        return;
      }

      setState(() {
        _invitation = invitation;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Unable to load this invitation.';
      });
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  void _goToLogin() {
    final invitationId = widget.invitationId.trim();

    if (invitationId.isEmpty) {
      return;
    }

    final location =
        '${RouteNames.login}'
        '?invitationId='
        '${Uri.encodeComponent(invitationId)}';

    context.push(location);
  }

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> _acceptInvitation() async {
    final invitation = _invitation;

    if (invitation == null || _isAccepting) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _goToLogin();
      return;
    }

    // ----------------------------------------------------------
    // FIREBASE PHONE
    // ----------------------------------------------------------

    final firebasePhone = user.phoneNumber?.trim();

    if (firebasePhone == null || firebasePhone.isEmpty) {
      setState(() {
        _error = 'Your Firebase phone number is not available.';
      });

      return;
    }

    final normalizedFirebasePhone = PhoneNumberUtils.normalizeAndValidate(
      firebasePhone,
    );

    final normalizedInvitationPhone = PhoneNumberUtils.normalizeAndValidate(
      invitation.phone,
    );

    // ----------------------------------------------------------
    // PHONE MATCH
    // ----------------------------------------------------------

    if (normalizedFirebasePhone != normalizedInvitationPhone) {
      setState(() {
        _error = 'This invitation belongs to a different phone number.';
      });

      return;
    }

    setState(() {
      _isAccepting = true;
      _error = null;
    });

    try {
      final linkAndAccept = ref.read(linkAndAcceptTenantInvitationProvider);

      await linkAndAccept(invitationId: invitation.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _isAccepting = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Invitation Accepted'),
            content: const Text(
              'Your tenant account has been linked successfully.',
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
        _error = _cleanError(error);
      });
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Invitation')),
      body: SafeArea(child: _buildBody()),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildLoginView();
    }

    if (_error != null && _invitation == null) {
      return _buildErrorView();
    }

    final invitation = _invitation;

    if (invitation == null) {
      return const Center(child: Text('Invitation not found.'));
    }

    return _buildInvitationView(invitation);
  }

  // ============================================================
  // LOGIN VIEW
  // ============================================================

  Widget _buildLoginView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.mail_outline, size: 72),
          const SizedBox(height: 24),
          Text(
            'You Have a Tenant Invitation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in with the invited phone number to view and accept this invitation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _goToLogin,
              child: const Text('Login & Accept'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You must use the phone number that received the invitation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INVITATION VIEW
  // ============================================================

  Widget _buildInvitationView(TenantInvitation invitation) {
    final user = FirebaseAuth.instance.currentUser;

    final isLoggedIn = user != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.mail_outline, size: 72),
          const SizedBox(height: 24),
          Text(
            'You Have a Tenant Invitation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'A property owner has invited you to join their property as a tenant.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invitation Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(label: 'Phone', value: invitation.phone),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Property', value: invitation.propertyId),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Unit', value: invitation.unitId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isAccepting ? null : _acceptInvitation,
              child: _isAccepting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isLoggedIn ? 'Accept Invitation' : 'Login & Accept'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your signed-in phone number must match this invitation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Invitation not found.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadInvitation,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DETAIL ROW
// ================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
