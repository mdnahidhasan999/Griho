import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/tenant.dart';
import '../../domain/usecases/link_and_accept_tenant_invitation.dart';
import '../providers/link_and_accept_tenant_invitation_provider.dart';

// ================================================================
// STATE
// ================================================================

class TenantAccountLinkState {
  final bool isLoading;
  final Tenant? tenant;
  final String? errorMessage;
  final bool completed;

  const TenantAccountLinkState({
    this.isLoading = false,
    this.tenant,
    this.errorMessage,
    this.completed = false,
  });

  TenantAccountLinkState copyWith({
    bool? isLoading,
    Tenant? tenant,
    String? errorMessage,
    bool? completed,
    bool clearError = false,
    bool clearTenant = false,
  }) {
    return TenantAccountLinkState(
      isLoading: isLoading ?? this.isLoading,
      tenant: clearTenant ? null : tenant ?? this.tenant,
      errorMessage:
      clearError ? null : errorMessage ?? this.errorMessage,
      completed: completed ?? this.completed,
    );
  }
}

// ================================================================
// CONTROLLER
// ================================================================

class TenantAccountLinkController
    extends StateNotifier<TenantAccountLinkState> {
  final LinkAndAcceptTenantInvitation _linkAndAcceptTenantInvitation;

  TenantAccountLinkController({
    required this._linkAndAcceptTenantInvitation,
  }) : super(const TenantAccountLinkState());

  // ==============================================================
  // LINK + ACCEPT
  // ==============================================================

  Future<Tenant?> linkAndAccept({
    required String tenantId,
    required String userId,
    required String invitationId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      completed: false,
    );

    try {
      final tenant = await _linkAndAcceptTenantInvitation(
        tenantId: tenantId,
        userId: userId,
        invitationId: invitationId,
      );

      state = state.copyWith(
        isLoading: false,
        tenant: tenant,
        completed: true,
        clearError: true,
      );

      return tenant;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
        completed: false,
      );

      return null;
    }
  }

  // ==============================================================
  // CLEAR
  // ==============================================================

  void clear() {
    state = const TenantAccountLinkState();
  }
}

// ================================================================
// PROVIDER
// ================================================================

final tenantAccountLinkControllerProvider =
StateNotifierProvider<
    TenantAccountLinkController,
    TenantAccountLinkState>(
      (ref) {
    return TenantAccountLinkController(
      linkAndAcceptTenantInvitation: ref.read(
        linkAndAcceptTenantInvitationProvider,
      ),
    );
  },
);