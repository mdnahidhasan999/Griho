import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/tenant_invitation.dart';

import '../../domain/usecases/accept_tenant_invitation.dart';
import '../../domain/usecases/cancel_tenant_invitation.dart';
import '../../domain/usecases/create_tenant_invitation.dart';
import '../../domain/usecases/expire_tenant_invitation.dart';
import '../../domain/usecases/get_invitation_by_token.dart';
import '../../domain/usecases/get_pending_tenant_invitation.dart';
import '../../domain/usecases/get_tenant_invitation.dart';
import '../providers/tenant_invitation_provider.dart';

// ================================================================
// TENANT INVITATION CONTROLLER
// ================================================================

class TenantInvitationController
    extends StateNotifier<AsyncValue<TenantInvitation?>> {
  final CreateTenantInvitation _createInvitation;
  final GetTenantInvitation _getInvitation;
  final GetInvitationByToken _getInvitationByToken;
  final GetPendingTenantInvitation _getPendingInvitation;
  final AcceptTenantInvitation _acceptInvitation;
  final CancelTenantInvitation _cancelInvitation;
  final ExpireTenantInvitation _expireInvitation;

  TenantInvitationController({
    required this._createInvitation,
    required this._getInvitation,
    required this._getInvitationByToken,
    required this._getPendingInvitation,
    required this._acceptInvitation,
    required this._cancelInvitation,
    required this._expireInvitation,
  }) : super(const AsyncData(null));

  // ==============================================================
  // CREATE INVITATION
  // ==============================================================

  Future<TenantInvitation?> createInvitation({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  }) async {
    state = const AsyncLoading();

    try {
      final invitation = await _createInvitation(
        tenantId: tenantId,
        propertyId: propertyId,
        unitId: unitId,
        phone: phone,
      );

      state = AsyncData(invitation);

      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // GET INVITATION BY ID
  // ==============================================================

  Future<TenantInvitation?> getInvitation(String invitationId,) async {
    state = const AsyncLoading();

    try {
      final invitation = await _getInvitation(
        invitationId,
      );

      state = AsyncData(invitation);

      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // GET INVITATION BY TOKEN
  //
  // Used during tenant registration.
  // ==============================================================

  Future<TenantInvitation?> getInvitationByToken(String token,) async {
    state = const AsyncLoading();

    try {
      final invitation =
      await _getInvitationByToken(
        token,
      );

      state = AsyncData(invitation);

      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // GET PENDING INVITATION
  //
  // Used by owner.
  // ==============================================================

  Future<TenantInvitation?> getPendingInvitation(String tenantId,) async {
    state = const AsyncLoading();

    try {
      final invitation =
      await _getPendingInvitation(
        tenantId,
      );

      state = AsyncData(invitation);

      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return null;
    }
  }

  // ==============================================================
  // ACCEPT INVITATION
  // ==============================================================

  Future<bool> acceptInvitation(String invitationId,) async {
    state = const AsyncLoading();

    try {
      await _acceptInvitation(
        invitationId,
      );

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  // ==============================================================
  // CANCEL INVITATION
  // ==============================================================

  Future<bool> cancelInvitation(String invitationId,) async {
    state = const AsyncLoading();

    try {
      await _cancelInvitation(
        invitationId,
      );

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  // ==============================================================
  // EXPIRE INVITATION
  // ==============================================================

  Future<bool> expireInvitation(String invitationId,) async {
    state = const AsyncLoading();

    try {
      await _expireInvitation(
        invitationId,
      );

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  // ==============================================================
  // CLEAR
  // ==============================================================

  void clear() {
    state = const AsyncData(null);
  }
}

// ================================================================
// CONTROLLER PROVIDER
// ================================================================

final tenantInvitationControllerProvider =
StateNotifierProvider<
    TenantInvitationController,
    AsyncValue<TenantInvitation?>>(
      (ref) {
    return TenantInvitationController(
      createInvitation: ref.read(
        createTenantInvitationProvider,
      ),
      getInvitation: ref.read(
        getTenantInvitationProvider,
      ),
      getInvitationByToken: ref.read(
        getInvitationByTokenProvider,
      ),
      getPendingInvitation: ref.read(
        getPendingTenantInvitationProvider,
      ),
      acceptInvitation: ref.read(
        acceptTenantInvitationProvider,
      ),
      cancelInvitation: ref.read(
        cancelTenantInvitationProvider,
      ),
      expireInvitation: ref.read(
        expireTenantInvitationProvider,
      ),
    );
  },
);