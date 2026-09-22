import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/user_profile_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../../domain/entities/tenancy_history.dart';
import '../controllers/tenant_controller.dart';
import 'tenant_invitation_provider.dart';
import 'tenancy_history_provider.dart';

/// =========================================================================
/// CURRENT AUTH USER
/// =========================================================================

final currentFirebaseUserProvider = Provider<User?>((ref) {
  return FirebaseAuth.instance.currentUser;
});

/// =========================================================================
/// CURRENT APP USER PROFILE
/// =========================================================================

final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return null;
  }

  final userId = firebaseUser.uid.trim();

  if (userId.isEmpty) {
    return null;
  }

  final dataSource = ref.read(userProfileDataSourceProvider);

  return dataSource.getUserByUid(userId);
});

/// =========================================================================
/// CURRENT TENANT
/// =========================================================================

final currentTenantProvider = FutureProvider<Tenant?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return null;
  }

  final userId = firebaseUser.uid.trim();

  if (userId.isEmpty) {
    return null;
  }

  final repository = ref.read(tenantRepositoryProvider);

  return repository.getTenantByUserId(userId);
});

/// =========================================================================
/// CURRENT TENANT ACTIVE STATUS
/// =========================================================================

final hasActiveTenancyProvider = FutureProvider<bool>((ref) async {
  final tenant = await ref.watch(currentTenantProvider.future);

  if (tenant == null) {
    return false;
  }

  return tenant.status == TenantStatus.active;
});

/// =========================================================================
/// PENDING INVITATION FOR CURRENT TENANT
/// =========================================================================
///
/// Invitation lookup is tenantId-based.
///
/// This uses the realtime Firestore stream provided by
/// pendingTenantInvitationStreamProvider.
///
/// No phone-number invitation query is used here.
///

final pendingTenantInvitationForCurrentUserProvider =
StreamProvider<TenantInvitation?>((ref) async* {
  final tenant = await ref.watch(
    currentTenantProvider.future,
  );

  if (tenant == null) {
    yield null;
    return;
  }

  final tenantId = tenant.id.trim();

  if (tenantId.isEmpty) {
    yield null;
    return;
  }

  final repository = ref.read(
    tenantInvitationRepositoryProvider,
  );

  yield* repository.watchPendingInvitationByTenantId(
    tenantId,
  );
});

/// =========================================================================
/// TENANCY HISTORY FOR CURRENT ACCOUNT
/// =========================================================================

final currentUserTenancyHistoryProvider =
FutureProvider<List<TenancyHistory>>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return const [];
  }

  final userId = firebaseUser.uid.trim();

  if (userId.isEmpty) {
    return const [];
  }

  return ref.watch(
    myTenancyHistoryProvider(userId).future,
  );
});

/// =========================================================================
/// CURRENT PROPERTY
/// =========================================================================
///
/// Loads the property belonging to the current tenant record.
///
/// If there is no tenant record, this returns null.
///

final currentTenantPropertyProvider =
FutureProvider<Property?>((ref) async {
  final tenant = await ref.watch(
    currentTenantProvider.future,
  );

  if (tenant == null) {
    return null;
  }

  final propertyId = tenant.propertyId.trim();

  if (propertyId.isEmpty) {
    return null;
  }

  return ref.watch(
    propertyByIdProvider(propertyId).future,
  );
});

/// =========================================================================
/// CURRENT UNIT
/// =========================================================================
///
/// Loads the unit belonging to the current tenant record.
///
/// If there is no tenant record, this returns null.
///

final currentTenantUnitProvider =
FutureProvider<Unit?>((ref) async {
  final tenant = await ref.watch(
    currentTenantProvider.future,
  );

  if (tenant == null) {
    return null;
  }

  final unitId = tenant.unitId.trim();

  if (unitId.isEmpty) {
    return null;
  }

  return ref.watch(
    unitByIdProvider(unitId).future,
  );
});

/// =========================================================================
/// TENANT DASHBOARD DATA
/// =========================================================================

class TenantDashboardData {
  final User? firebaseUser;
  final AppUser? appUser;
  final Tenant? tenant;
  final Property? currentProperty;
  final Unit? currentUnit;
  final TenantInvitation? pendingInvitation;
  final List<TenancyHistory> tenancyHistory;

  const TenantDashboardData({
    required this.firebaseUser,
    required this.appUser,
    required this.tenant,
    required this.currentProperty,
    required this.currentUnit,
    required this.pendingInvitation,
    required this.tenancyHistory,
  });

  /// Whether the user has a linked tenant record.
  bool get hasTenant {
    return tenant != null;
  }

  /// Whether the user currently has an active tenancy.
  bool get hasActiveTenancy {
    return tenant?.status == TenantStatus.active;
  }

  /// Whether the account currently has a valid pending invitation.
  bool get hasPendingInvitation {
    return pendingInvitation?.isValid == true;
  }

  /// Whether the user has any previous tenancy records.
  bool get hasTenancyHistory {
    return tenancyHistory.isNotEmpty;
  }

  /// Whether the user is authenticated.
  bool get isAuthenticated {
    return firebaseUser != null;
  }

  /// Display name priority:
  ///
  /// 1. Griho profile name
  /// 2. Firebase display name
  /// 3. Tenant name
  /// 4. Generic fallback
  String get displayName {
    final profileName = appUser?.name.trim();

    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final firebaseDisplayName =
    firebaseUser?.displayName?.trim();

    if (firebaseDisplayName != null &&
        firebaseDisplayName.isNotEmpty) {
      return firebaseDisplayName;
    }

    final tenantName = tenant?.name.trim();

    if (tenantName != null && tenantName.isNotEmpty) {
      return tenantName;
    }

    return 'Tenant';
  }

  /// Current authenticated Firebase UID.
  String? get userId {
    final uid = firebaseUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  /// Current authenticated phone number.
  String? get phoneNumber {
    final phone = firebaseUser?.phoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      return null;
    }

    return phone;
  }

  /// Whether the Griho profile is available.
  bool get hasProfile {
    return appUser != null;
  }

  /// Whether the account currently has no active tenancy.
  ///
  /// This is a valid dashboard state, not an error state.
  bool get isWithoutActiveTenancy {
    return !hasActiveTenancy;
  }

  /// Display name for the current property.
  String? get currentPropertyName {
    final name = currentProperty?.name.trim();

    if (name == null || name.isEmpty) {
      return null;
    }

    return name;
  }

  /// Display value for the current unit.
  ///
  /// Priority:
  ///
  /// 1. Unit name
  /// 2. Unit number
  ///
  /// Never returns the internal Firestore unit ID.
  String? get currentUnitDisplayName {
    final unitName = currentUnit?.name?.trim();

    if (unitName != null && unitName.isNotEmpty) {
      return unitName;
    }

    final unitNumber = currentUnit?.unitNumber.trim();

    if (unitNumber != null && unitNumber.isNotEmpty) {
      return unitNumber;
    }

    return null;
  }

  /// Empty dashboard data.
  factory TenantDashboardData.empty() {
    return const TenantDashboardData(
      firebaseUser: null,
      appUser: null,
      tenant: null,
      currentProperty: null,
      currentUnit: null,
      pendingInvitation: null,
      tenancyHistory: [],
    );
  }
}

/// =========================================================================
/// TENANT DASHBOARD PROVIDER
/// =========================================================================
///
/// Loads all tenant-home information together.
///
/// Data sources:
///
/// - App profile
/// - Tenant record
/// - Property
/// - Unit
/// - Pending invitation
/// - Tenancy history
///
/// Pending invitations are resolved by tenantId.
///

final tenantDashboardProvider =
FutureProvider<TenantDashboardData>((ref) async {
  final firebaseUser = ref.watch(
    currentFirebaseUserProvider,
  );

  if (firebaseUser == null) {
    return TenantDashboardData.empty();
  }

  final appUserFuture = ref.watch(
    currentAppUserProvider.future,
  );

  final tenantFuture = ref.watch(
    currentTenantProvider.future,
  );

  final propertyFuture = ref.watch(
    currentTenantPropertyProvider.future,
  );

  final unitFuture = ref.watch(
    currentTenantUnitProvider.future,
  );

  final historyFuture = ref.watch(
    currentUserTenancyHistoryProvider.future,
  );

  final invitationFuture = ref.watch(
    pendingTenantInvitationForCurrentUserProvider.future,
  );

  final results = await Future.wait<dynamic>([
    appUserFuture,
    tenantFuture,
    propertyFuture,
    unitFuture,
    invitationFuture,
    historyFuture,
  ]);

  return TenantDashboardData(
    firebaseUser: firebaseUser,
    appUser: results[0] as AppUser?,
    tenant: results[1] as Tenant?,
    currentProperty: results[2] as Property?,
    currentUnit: results[3] as Unit?,
    pendingInvitation: results[4] as TenantInvitation?,
    tenancyHistory: results[5] as List<TenancyHistory>,
  );
});