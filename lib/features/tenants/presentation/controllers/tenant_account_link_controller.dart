import 'package:flutter_riverpod/legacy.dart';

import '../../domain/usecases/link_and_accept_tenant_invitation.dart';
import '../providers/link_and_accept_tenant_invitation_provider.dart';

// ================================================================
// STATE
// ================================================================

class TenantAccountLinkState {
  final bool isLoading;
  final String? errorMessage;
  final bool completed;

  const TenantAccountLinkState({
    this.isLoading = false,
    this.errorMessage,
    this.completed = false,
  });

  TenantAccountLinkState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? completed,
    bool clearError = false,
  }) {
    return TenantAccountLinkState(
      isLoading: isLoading ?? this.isLoading,
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

  Future<bool> linkAndAccept({
    required String invitationId,
  }) async {
    if (state.isLoading) {
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      completed: false,
    );

    try {
      await _linkAndAcceptTenantInvitation(
        invitationId: invitationId,
      );

      state = state.copyWith(
        isLoading: false,
        completed: true,
        clearError: true,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(error),
        completed: false,
      );

      return false;
    }
  }

  // ==============================================================
  // CLEAR
  // ==============================================================

  void clear() {
    state = const TenantAccountLinkState();
  }

  // ==============================================================
  // ERROR
  // ==============================================================

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}

// ================================================================
// PROVIDER
// ================================================================

final tenantAccountLinkControllerProvider =
StateNotifierProvider<
    TenantAccountLinkController,
    TenantAccountLinkState
>(
      (ref) {
    return TenantAccountLinkController(
      linkAndAcceptTenantInvitation: ref.read(
        linkAndAcceptTenantInvitationProvider,
      ),
    );
  },
);