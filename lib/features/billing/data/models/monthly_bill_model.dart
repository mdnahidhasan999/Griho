import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../rents/domain/entities/monthly_rent.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';

typedef JsonMap = Map<String, dynamic>;

class MonthlyBillModel extends MonthlyBill {
  const MonthlyBillModel({
    required super.id,
    super.billCollection = 'monthlyBills',
    required super.ownerId,
    required super.propertyId,
    required super.floorId,
    required super.unitId,
    required super.tenantId,
    super.tenantUserId,
    super.tenancyHistoryId,
    super.title,
    super.ruleScopeType,
    super.ruleScopeId,
    super.ruleSnapshot,
    super.overriddenFromRuleId,
    super.overriddenFromAmount,
    required super.sourceRuleId,
    required super.type,
    required super.valueType,
    required super.amount,
    required super.paidAmount,
    required super.billingPeriodStart,
    required super.billingPeriodEnd,
    required super.dueDate,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  // ==========================================================================
  // FROM FIRESTORE
  // ==========================================================================

  factory MonthlyBillModel.fromFirestore(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Monthly bill document ${doc.id} has no data.');
    }

    return MonthlyBillModel(
      id: doc.id,
      billCollection: 'monthlyBills',
      ownerId: _readRequiredString(data, 'ownerId'),
      propertyId: _readRequiredString(data, 'propertyId'),
      floorId: _readOptionalString(data, 'floorId') ?? '',
      unitId: _readRequiredString(data, 'unitId'),
      tenantId: _readRequiredString(data, 'tenantId'),
      tenantUserId: _readOptionalString(data, 'tenantUserId'),
      tenancyHistoryId: _readOptionalString(data, 'tenancyHistoryId'),
      title: _readOptionalString(data, 'title'),
      ruleScopeType: _readOptionalScopeType(data, 'ruleScopeType'),
      ruleScopeId: _readOptionalString(data, 'ruleScopeId'),
      ruleSnapshot: _readOptionalMap(data, 'ruleSnapshot'),
      overriddenFromRuleId: _readOptionalString(data, 'overriddenFromRuleId'),
      overriddenFromAmount: _readOptionalDouble(data, 'overriddenFromAmount'),
      sourceRuleId: _readRequiredString(data, 'sourceRuleId'),
      type: _readBillType(data),
      valueType: _readBillValueType(data),
      amount: _readRequiredDouble(data, 'amount'),
      paidAmount: _readRequiredDouble(data, 'paidAmount'),
      billingPeriodStart: _readRequiredDateTime(data, 'billingPeriodStart'),
      billingPeriodEnd: _readRequiredDateTime(data, 'billingPeriodEnd'),
      dueDate: _readRequiredDateTime(data, 'dueDate'),
      status: _readBillStatus(data),
      createdAt: _readRequiredDateTime(data, 'createdAt'),
      updatedAt: _readRequiredDateTime(data, 'updatedAt'),
    );
  }

  // ==========================================================================
  // FROM MONTHLY RENT (COMBINED RENT + BILL ADAPTER)
  // ==========================================================================

  factory MonthlyBillModel.fromMonthlyRent(
    MonthlyRent rent, {
    String floorId = '',
  }) {
    final rentTitle = rent.isProrated
        ? 'House rent (${rent.chargeableDays}/${rent.daysInBillingPeriod} days)'
        : 'House rent';

    return MonthlyBillModel(
      id: rent.id,
      billCollection: 'monthlyRents',
      ownerId: rent.ownerId,
      propertyId: rent.propertyId,
      floorId: floorId,
      unitId: rent.unitId,
      tenantId: rent.tenantId,
      tenantUserId: rent.tenantUserId,
      sourceRuleId: rent.rentRateId,
      title: rentTitle,
      ruleScopeType: BillingScopeType.unit,
      ruleScopeId: rent.unitId,
      ruleSnapshot: {
        'rentRateId': rent.rentRateId,
        'monthlyRate': rent.monthlyRate,
        'chargeableDays': rent.chargeableDays,
        'daysInBillingPeriod': rent.daysInBillingPeriod,
        'prorationFactor': rent.prorationFactor,
        'chargePeriodStart': rent.chargePeriodStart.toIso8601String(),
        'chargePeriodEnd': rent.chargePeriodEnd.toIso8601String(),
      },
      type: MonthlyBillType.rent,
      valueType: BillingValueType.fixed,
      amount: rent.amount,
      paidAmount: rent.paidAmount,
      billingPeriodStart: rent.billingPeriodStart,
      billingPeriodEnd: rent.billingPeriodEnd,
      dueDate: rent.dueDate,
      status: _mapRentStatus(rent.status),
      createdAt: rent.createdAt,
      updatedAt: rent.updatedAt,
    );
  }

  static MonthlyBillStatus _mapRentStatus(MonthlyRentStatus rentStatus) {
    switch (rentStatus) {
      case MonthlyRentStatus.unpaid:
        return MonthlyBillStatus.unpaid;
      case MonthlyRentStatus.partiallyPaid:
        return MonthlyBillStatus.partiallyPaid;
      case MonthlyRentStatus.paid:
        return MonthlyBillStatus.paid;
      case MonthlyRentStatus.overdue:
        return MonthlyBillStatus.overdue;
      case MonthlyRentStatus.cancelled:
        return MonthlyBillStatus.cancelled;
    }
  }

  // ==========================================================================
  // TO FIRESTORE
  // ==========================================================================

  JsonMap toFirestore() {
    return {
      'ownerId': ownerId,
      'propertyId': propertyId,
      'floorId': floorId,
      'unitId': unitId,
      'tenantId': tenantId,
      'tenantUserId': tenantUserId,
      'tenancyHistoryId': tenancyHistoryId,
      'title': title,
      'ruleScopeType': ruleScopeType?.name,
      'ruleScopeId': ruleScopeId,
      'ruleSnapshot': ruleSnapshot,
      'overriddenFromRuleId': overriddenFromRuleId,
      'overriddenFromAmount': overriddenFromAmount,
      'sourceRuleId': sourceRuleId,
      'type': type.name,
      'valueType': valueType.name,
      'amount': amount,
      'paidAmount': paidAmount,
      'billingPeriodStart': Timestamp.fromDate(billingPeriodStart),
      'billingPeriodEnd': Timestamp.fromDate(billingPeriodEnd),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ==========================================================================
  // COPY WITH MODEL
  // ==========================================================================

  MonthlyBillModel copyWithModel({
    String? id,
    String? billCollection,
    String? ownerId,
    String? propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    String? tenancyHistoryId,
    bool clearTenancyHistoryId = false,
    String? title,
    bool clearTitle = false,
    BillingScopeType? ruleScopeType,
    String? ruleScopeId,
    JsonMap? ruleSnapshot,
    String? overriddenFromRuleId,
    double? overriddenFromAmount,
    String? sourceRuleId,
    MonthlyBillType? type,
    BillingValueType? valueType,
    double? amount,
    double? paidAmount,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    DateTime? dueDate,
    MonthlyBillStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTenantUserId = false,
  }) {
    return MonthlyBillModel(
      id: id ?? this.id,
      billCollection: billCollection ?? this.billCollection,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      floorId: floorId ?? this.floorId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId: clearTenantUserId
          ? null
          : tenantUserId ?? this.tenantUserId,
      tenancyHistoryId: clearTenancyHistoryId
          ? null
          : tenancyHistoryId ?? this.tenancyHistoryId,
      title: clearTitle ? null : title ?? this.title,
      ruleScopeType: ruleScopeType ?? this.ruleScopeType,
      ruleScopeId: ruleScopeId ?? this.ruleScopeId,
      ruleSnapshot: ruleSnapshot ?? this.ruleSnapshot,
      overriddenFromRuleId: overriddenFromRuleId ?? this.overriddenFromRuleId,
      overriddenFromAmount: overriddenFromAmount ?? this.overriddenFromAmount,
      sourceRuleId: sourceRuleId ?? this.sourceRuleId,
      type: type ?? this.type,
      valueType: valueType ?? this.valueType,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      billingPeriodStart: billingPeriodStart ?? this.billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd ?? this.billingPeriodEnd,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ==========================================================================
  // READ HELPERS
  // ==========================================================================

  static String _readRequiredString(JsonMap data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Monthly bill field "$field" '
        'is missing or invalid.',
      );
    }

    return value.trim();
  }

  static String? _readOptionalString(JsonMap data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError('Monthly bill field "$field" is invalid.');
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static double _readRequiredDouble(JsonMap data, String field) {
    final value = data[field];

    if (value is! num) {
      throw StateError(
        'Monthly bill field "$field" '
        'is missing or invalid.',
      );
    }

    final result = value.toDouble();

    if (result < 0) {
      throw StateError(
        'Monthly bill field "$field" '
        'cannot be negative.',
      );
    }

    return result;
  }

  static double? _readOptionalDouble(JsonMap data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! num) {
      return null;
    }

    return value.toDouble();
  }

  static BillingScopeType? _readOptionalScopeType(JsonMap data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    for (final scope in BillingScopeType.values) {
      if (scope.name == value.trim()) {
        return scope;
      }
    }

    return null;
  }

  static JsonMap? _readOptionalMap(JsonMap data, String field) {
    final value = data[field];

    if (value is JsonMap) {
      return JsonMap.unmodifiable(value);
    }

    if (value is Map) {
      return JsonMap.unmodifiable(
        value.map((key, val) => MapEntry(key.toString(), val)),
      );
    }

    return null;
  }

  static DateTime _readRequiredDateTime(JsonMap data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError(
      'Monthly bill field "$field" '
      'is missing or invalid.',
    );
  }

  // ==========================================================================
  // BILL TYPE
  // ==========================================================================

  static MonthlyBillType _readBillType(JsonMap data) {
    final value = data['type'];

    if (value is! String) {
      throw StateError(
        'Monthly bill field "type" '
        'is missing or invalid.',
      );
    }

    return MonthlyBillType.values.firstWhere(
      (type) => type.name == value,
      orElse: () {
        throw StateError('Unknown monthly bill type: $value');
      },
    );
  }

  // ==========================================================================
  // BILL VALUE TYPE
  // ==========================================================================

  static BillingValueType _readBillValueType(JsonMap data) {
    final value = data['valueType'];

    if (value is! String) {
      throw StateError(
        'Monthly bill field "valueType" '
        'is missing or invalid.',
      );
    }

    return BillingValueType.values.firstWhere(
      (type) => type.name == value,
      orElse: () {
        throw StateError('Unknown billing value type: $value');
      },
    );
  }

  // ==========================================================================
  // BILL STATUS
  // ==========================================================================

  static MonthlyBillStatus _readBillStatus(JsonMap data) {
    final value = data['status'];

    if (value is! String) {
      throw StateError(
        'Monthly bill field "status" '
        'is missing or invalid.',
      );
    }

    return MonthlyBillStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () {
        throw StateError('Unknown monthly bill status: $value');
      },
    );
  }
}
