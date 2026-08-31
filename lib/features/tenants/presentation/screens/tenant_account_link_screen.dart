import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../controllers/tenant_account_link_controller.dart';

class TenantAccountLinkScreen extends ConsumerStatefulWidget {
  final String invitationId;

  const TenantAccountLinkScreen({super.key, required this.invitationId});

  @override
  ConsumerState<TenantAccountLinkScreen> createState() =>
      _TenantAccountLinkScreenState();
}

class _TenantAccountLinkScreenState
    extends ConsumerState<TenantAccountLinkScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkAccount();
    });
  }

  // ============================================================
  // LINK ACCOUNT
  // ============================================================

  Future<void> _linkAccount() async {
    if (_started) {
      return;
    }

    _started = true;

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to link your tenant account.'),
        ),
      );

      _started = false;

      return;
    }

    final invitationId = widget.invitationId.trim();

    if (invitationId.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation ID is missing.')),
      );

      _started = false;

      return;
    }

    await ref
        .read(tenantAccountLinkControllerProvider.notifier)
        .linkAndAccept(invitationId: invitationId);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantAccountLinkControllerProvider);

    ref.listen<TenantAccountLinkState>(tenantAccountLinkControllerProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (next.completed && previous?.completed != true) {
        context.go(RouteNames.tenantHome);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Link Tenant Account')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBody(state),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(TenantAccountLinkState state) {
    if (state.isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Linking your tenant account...', textAlign: TextAlign.center),
        ],
      );
    }

    if (state.completed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64),
          SizedBox(height: 16),
          Text(
            'Tenant account linked successfully.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off, size: 64),
        const SizedBox(height: 16),
        Text(
          state.errorMessage ?? 'Unable to link your tenant account.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _linkAccount, child: const Text('Try Again')),
      ],
    );
  }
}
