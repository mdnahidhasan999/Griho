// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant_invitation.dart';
import '../../domain/usecases/accept_tenant_invitation.dart';
import '../../domain/usecases/cancel_tenant_invitation.dart';
import '../../domain/usecases/create_tenant_invitation.dart';
import '../../domain/usecases/expire_tenant_invitation.dart';
import '../../domain/usecases/get_invitation_by_token.dart';
import '../../domain/usecases/get_pending_invitation_by_phone.dart';
import '../../domain/usecases/get_pending_tenant_invitation.dart';
import '../../domain/usecases/get_tenant_invitation.dart';
import '../providers/tenant_invitation_provider.dart';

class TenantInvitationController
    extends Notifier<AsyncValue<TenantInvitation?>> {
  late final CreateTenantInvitation _createInvitation;
  late final GetTenantInvitation _getInvitation;
  late final GetInvitationByToken _getInvitationByToken;
  late final GetPendingTenantInvitation _getPendingInvitation;
  late final GetPendingInvitationByPhone _getPendingInvitationByPhone;
  late final AcceptTenantInvitation _acceptInvitation;
  late final CancelTenantInvitation _cancelInvitation;
  late final ExpireTenantInvitation _expireInvitation;

  @override
  AsyncValue<TenantInvitation?> build() {
    _createInvitation = ref.read(createTenantInvitationProvider);
    _getInvitation = ref.read(getTenantInvitationProvider);
    _getInvitationByToken = ref.read(getInvitationByTokenProvider);
    _getPendingInvitation = ref.read(getPendingTenantInvitationProvider);
    _getPendingInvitationByPhone = ref.read(
      getPendingInvitationByPhoneProvider,
    );
    _acceptInvitation = ref.read(acceptTenantInvitationProvider);
    _cancelInvitation = ref.read(cancelTenantInvitationProvider);
    _expireInvitation = ref.read(expireTenantInvitationProvider);
    return const AsyncData(null);
  }

  Future<TenantInvitation?> createInvitation({
    String? tenantId,
    required String propertyId,
    required String unitId,
    String? phone,
    String? targetName,
    String? targetEmail,
    String? targetGrihoId,
    required double rentAmount,
  }) async {
    state = const AsyncLoading();

    try {
      final invitation = await _createInvitation(
        tenantId: tenantId,
        propertyId: propertyId,
        unitId: unitId,
        phone: phone,
        targetName: targetName,
        targetEmail: targetEmail,
        targetGrihoId: targetGrihoId,
        rentAmount: rentAmount,
      );

      state = AsyncData(invitation);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<TenantInvitation?> getInvitation(String invitationId) async {
    state = const AsyncLoading();

    try {
      final invitation = await _getInvitation(invitationId);
      state = AsyncData(invitation);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<TenantInvitation?> getInvitationByToken(String token) async {
    state = const AsyncLoading();

    try {
      final invitation = await _getInvitationByToken(token);
      state = AsyncData(invitation);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<TenantInvitation?> getPendingInvitation(String tenantId) async {
    state = const AsyncLoading();

    try {
      final invitation = await _getPendingInvitation(tenantId);
      state = AsyncData(invitation);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<TenantInvitation?> getPendingInvitationByPhone(String phone) async {
    state = const AsyncLoading();

    try {
      final invitation = await _getPendingInvitationByPhone(phone);
      state = AsyncData(invitation);
      return invitation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<bool> acceptInvitation(String invitationId) async {
    state = const AsyncLoading();

    try {
      await _acceptInvitation(invitationId);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> cancelInvitation(String invitationId) async {
    state = const AsyncLoading();

    try {
      await _cancelInvitation(invitationId);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> expireInvitation(String invitationId) async {
    state = const AsyncLoading();

    try {
      await _expireInvitation(invitationId);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final tenantInvitationControllerProvider =
    NotifierProvider<TenantInvitationController, AsyncValue<TenantInvitation?>>(
      TenantInvitationController.new,
    );
