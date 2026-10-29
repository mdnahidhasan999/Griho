import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';

/// Maps documents from `monthlyRents` into the common MonthlyBill entity.
///
/// Rent documents have a different schema from monthlyBills.
/// For example, they may contain monthlyRate and rentRateId instead
/// of sourceRuleId, type, valueType and paidAmount.
class MonthlyRentModel extends MonthlyBill {
  const MonthlyRentModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.floorId,
    required super.unitId,
    required super.tenantId,
    super.tenantUserId,
    required super.sourceRuleId,
    super.tenancyHistoryId,
    required super.amount,
    required super.paidAmount,
    required super.billingPeriodStart,
    required super.billingPeriodEnd,
    required super.dueDate,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  }) : super(
    billCollection: 'monthlyRents',
    type: MonthlyBillType.rent,
    valueType: BillingValueType.fixed,
  );

  factory MonthlyRentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Monthly rent document ${document.id} has no data.',
      );
    }

    final amount = _readNumber(data, 'amount');

    final paidAmount = _readOptionalNumber(
      data,
      'paidAmount',
      defaultValue: 0,
    );

    final billingPeriodStart = _readDate(data, 'billingPeriodStart');
    final billingPeriodEnd = _readDate(data, 'billingPeriodEnd');

    final status = _readStatus(data['status']);

    return MonthlyRentModel(
      id: document.id,
      ownerId: _readRequiredString(data, 'ownerId'),
      propertyId: _readRequiredString(data, 'propertyId'),

      // The provided monthlyRents screenshot does not show floorId.
      // An empty string is used only for the common display entity.
      // Payment confirmation must not depend on this fallback.
      floorId: _readOptionalString(data, 'floorId') ?? '',

      unitId: _readRequiredString(data, 'unitId'),
      tenantId: _readRequiredString(data, 'tenantId'),
      tenantUserId: _readOptionalString(data, 'tenantUserId'),

      // Rent records use rentRateId rather than sourceRuleId.
      sourceRuleId:
      _readOptionalString(data, 'rentRateId') ??
          _readOptionalString(data, 'sourceRuleId') ??
          document.id,

      tenancyHistoryId: _readOptionalString(data, 'tenancyHistoryId'),

      amount: amount,
      paidAmount: paidAmount,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      dueDate: _readDate(data, 'dueDate'),
      status: status,
      createdAt: _readOptionalDate(data, 'createdAt') ?? billingPeriodStart,
      updatedAt: _readOptionalDate(data, 'updatedAt') ?? billingPeriodStart,
    );
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Monthly rent field "$field" is missing or invalid.',
      );
    }

    return value.trim();
  }

  static String? _readOptionalString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static double _readNumber(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! num) {
      throw StateError(
        'Monthly rent field "$field" is missing or invalid.',
      );
    }

    final result = value.toDouble();

    if (!result.isFinite || result < 0) {
      throw StateError(
        'Monthly rent field "$field" has an invalid amount.',
      );
    }

    return result;
  }

  static double _readOptionalNumber(
      Map<String, dynamic> data,
      String field, {
        required double defaultValue,
      }) {
    final value = data[field];

    if (value == null) {
      return defaultValue;
    }

    if (value is! num) {
      throw StateError(
        'Monthly rent field "$field" is invalid.',
      );
    }

    final result = value.toDouble();

    if (!result.isFinite || result < 0) {
      throw StateError(
        'Monthly rent field "$field" is invalid.',
      );
    }

    return result;
  }

  static DateTime _readDate(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw StateError(
      'Monthly rent field "$field" is missing or invalid.',
    );
  }

  static DateTime? _readOptionalDate(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static MonthlyBillStatus _readStatus(dynamic value) {
    if (value is! String) {
      throw StateError('Monthly rent status is missing or invalid.');
    }

    switch (value) {
      case 'unpaid':
        return MonthlyBillStatus.unpaid;

      case 'partiallyPaid':
        return MonthlyBillStatus.partiallyPaid;

      case 'paid':
        return MonthlyBillStatus.paid;

      case 'overdue':
        return MonthlyBillStatus.overdue;

      case 'cancelled':
        return MonthlyBillStatus.cancelled;

      default:
        throw StateError('Unknown monthly rent status: $value');
    }
  }
}