import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tenant_dashboard_provider.dart';
import '../providers/tenant_invitation_provider.dart';
import 'tenant_invitation_receive_screen.dart';
import '../../../home/presentation/screens/tenant_home_screen.dart';

class TenantHomeInvitationGateScreen
    extends ConsumerWidget {
  const TenantHomeInvitationGateScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final tenantAsync = ref.watch(
      currentTenantProvider,
    );

    return tenantAsync.when(
      loading: () {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load tenant information.\n\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
      data: (tenant) {
        if (tenant == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Tenant profile not found.',
              ),
            ),
          );
        }

        final pendingInvitationAsync = ref.watch(
          pendingTenantInvitationStreamProvider(
            tenant.id,
          ),
        );

        return pendingInvitationAsync.when(
          loading: () {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          error: (error, stackTrace) {
            return const TenantHomeScreen();
          },
          data: (invitation) {
            if (invitation == null) {
              return const TenantHomeScreen();
            }

            return TenantInvitationReceiveScreen(
              invitationId: invitation.id,
            );
          },
        );
      },
    );
  }
}