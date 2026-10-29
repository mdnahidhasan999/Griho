import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/user_profile_provider.dart';
import '../../../billing/domain/entities/monthly_bill.dart';
import '../../../billing/presentation/providers/monthly_bill_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenancy_history.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../controllers/tenant_controller.dart';
import 'tenancy_history_provider.dart';
import 'tenant_invitation_provider.dart';
import '../../../billing/domain/entities/billing_rule.dart';
import '../../../rents/domain/entities/monthly_rent.dart';

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

final pendingTenantInvitationForCurrentUserProvider =
    StreamProvider<TenantInvitation?>((ref) async* {
      final tenant = await ref.watch(currentTenantProvider.future);

      if (tenant == null) {
        yield null;
        return;
      }

      final tenantId = tenant.id.trim();

      if (tenantId.isEmpty) {
        yield null;
        return;
      }

      final repository = ref.read(tenantInvitationRepositoryProvider);

      yield* repository.watchPendingInvitationByTenantId(tenantId);
    });

/// =========================================================================
/// TENANCY HISTORY FOR CURRENT ACCOUNT
/// =========================================================================

final currentUserTenancyHistoryProvider = FutureProvider<List<TenancyHistory>>((
  ref,
) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return const [];
  }

  final userId = firebaseUser.uid.trim();

  if (userId.isEmpty) {
    return const [];
  }

  return ref.watch(myTenancyHistoryProvider(userId).future);
});

/// =========================================================================
/// CURRENT PROPERTY
/// =========================================================================

final currentTenantPropertyProvider = FutureProvider<Property?>((ref) async {
  final tenant = await ref.watch(currentTenantProvider.future);

  if (tenant == null) {
    return null;
  }

  final propertyId = tenant.propertyId.trim();

  if (propertyId.isEmpty) {
    return null;
  }

  return ref.watch(propertyByIdProvider(propertyId).future);
});

/// =========================================================================
/// CURRENT UNIT
/// =========================================================================

final currentTenantUnitProvider = FutureProvider<Unit?>((ref) async {
  final tenant = await ref.watch(currentTenantProvider.future);

  if (tenant == null) {
    return null;
  }

  final unitId = tenant.unitId.trim();

  if (unitId.isEmpty) {
    return null;
  }

  return ref.watch(unitByIdProvider(unitId).future);
});

/// =========================================================================
/// CURRENT MONTH
/// =========================================================================

final currentBillingPeriodStartProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, 1);
});

/// =========================================================================
/// CURRENT TENANT MONTHLY BILLS + RENT
/// =========================================================================

final currentTenantMonthlyBillsProvider = FutureProvider<List<MonthlyBill>>((
  ref,
) async {
  final tenant = await ref.watch(currentTenantProvider.future);

  if (tenant == null || tenant.status != TenantStatus.active) {
    return const <MonthlyBill>[];
  }

  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return const <MonthlyBill>[];
  }

  final String tenantUserId = firebaseUser.uid.trim();
  final String unitId = tenant.unitId.trim();

  if (tenantUserId.isEmpty || unitId.isEmpty) {
    return const <MonthlyBill>[];
  }

  final DateTime billingPeriodStart = ref.watch(
    currentBillingPeriodStartProvider,
  );

  final params = (
    tenantUserId: tenantUserId,
    billingPeriodStart: billingPeriodStart,
  );

  // Fetch bills and rents concurrently.
  final results = await Future.wait<dynamic>([
    ref.watch(monthlyBillsByTenantAndPeriodProvider(params).future),
    ref.watch(monthlyRentsByTenantAndPeriodProvider(params).future),
  ]);

  final List<MonthlyBill> bills = results[0] as List<MonthlyBill>;

  final List<MonthlyRent> rents = results[1] as List<MonthlyRent>;

  // Convert rent records into MonthlyBill for common display.
  final List<MonthlyBill> convertedRents = rents
      .map(_monthlyRentToBill)
      .toList();

  final combinedBills = <MonthlyBill>[...bills, ...convertedRents];

  // Only show bills belonging to the authenticated tenant
  // and the tenant's current unit.
  final currentUnitBills = combinedBills.where((bill) {
    return bill.unitId.trim() == unitId &&
        bill.tenantUserId?.trim() == tenantUserId;
  }).toList();

  // Deduplicate by collection + document ID.
  final uniqueBills = <String, MonthlyBill>{};

  for (final bill in currentUnitBills) {
    final key = '${bill.billCollection}/${bill.id}';
    uniqueBills[key] = bill;
  }

  // Sort rent first, then by due date.
  final sortedBills = uniqueBills.values.toList()
    ..sort((a, b) {
      if (a.type == MonthlyBillType.rent && b.type != MonthlyBillType.rent) {
        return -1;
      }

      if (a.type != MonthlyBillType.rent && b.type == MonthlyBillType.rent) {
        return 1;
      }

      final dateComparison = a.dueDate.compareTo(b.dueDate);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return a.id.compareTo(b.id);
    });

  return sortedBills;
});

/// =========================================================================
/// MONTHLY RENT -> COMMON MONTHLY BILL
/// =========================================================================

MonthlyBill _monthlyRentToBill(MonthlyRent rent) {
  final MonthlyBillStatus billStatus;

  switch (rent.status) {
    case MonthlyRentStatus.unpaid:
      billStatus = MonthlyBillStatus.unpaid;

    case MonthlyRentStatus.partiallyPaid:
      billStatus = MonthlyBillStatus.partiallyPaid;

    case MonthlyRentStatus.paid:
      billStatus = MonthlyBillStatus.paid;

    case MonthlyRentStatus.overdue:
      billStatus = MonthlyBillStatus.overdue;

    case MonthlyRentStatus.cancelled:
      billStatus = MonthlyBillStatus.cancelled;
  }

  return MonthlyBill(
    id: rent.id,
    billCollection: 'monthlyRents',
    ownerId: rent.ownerId,
    propertyId: rent.propertyId,
    floorId: '',
    unitId: rent.unitId,
    tenantId: rent.tenantId,
    tenantUserId: rent.tenantUserId,
    sourceRuleId: rent.rentRateId,
    type: MonthlyBillType.rent,
    valueType: BillingValueType.fixed,
    amount: rent.amount,
    paidAmount: rent.paidAmount,
    billingPeriodStart: rent.billingPeriodStart,
    billingPeriodEnd: rent.billingPeriodEnd,
    dueDate: rent.dueDate,
    status: billStatus,
    createdAt: rent.createdAt,
    updatedAt: rent.updatedAt,
  );
}

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

  bool get hasTenant {
    return tenant != null;
  }

  bool get hasActiveTenancy {
    return tenant?.status == TenantStatus.active;
  }

  bool get hasPendingInvitation {
    return pendingInvitation?.isPending == true;
  }

  bool get hasTenancyHistory {
    return tenancyHistory.isNotEmpty;
  }

  bool get isAuthenticated {
    return firebaseUser != null;
  }

  String get displayName {
    final profileName = appUser?.name.trim();

    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final firebaseDisplayName = firebaseUser?.displayName?.trim();

    if (firebaseDisplayName != null && firebaseDisplayName.isNotEmpty) {
      return firebaseDisplayName;
    }

    final tenantName = tenant?.name.trim();

    if (tenantName != null && tenantName.isNotEmpty) {
      return tenantName;
    }

    return 'Tenant';
  }

  String? get userId {
    final uid = firebaseUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  String? get phoneNumber {
    final phone = firebaseUser?.phoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      return null;
    }

    return phone;
  }

  bool get hasProfile {
    return appUser != null;
  }

  bool get isWithoutActiveTenancy {
    return !hasActiveTenancy;
  }

  String? get currentPropertyName {
    final name = currentProperty?.name.trim();

    if (name == null || name.isEmpty) {
      return null;
    }

    return name;
  }

  String? get currentUnitDisplayName {
    final unitName = currentUnit?.name?.trim();
    final unitNumber = currentUnit?.unitNumber.trim();

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

    return null;
  }

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

final tenantDashboardProvider = FutureProvider<TenantDashboardData>((
  ref,
) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return TenantDashboardData.empty();
  }

  final appUserFuture = ref.watch(currentAppUserProvider.future);
  final tenantFuture = ref.watch(currentTenantProvider.future);
  final propertyFuture = ref.watch(currentTenantPropertyProvider.future);
  final unitFuture = ref.watch(currentTenantUnitProvider.future);
  final historyFuture = ref.watch(currentUserTenancyHistoryProvider.future);
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
