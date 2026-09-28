import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';

class MonthlyBillModel extends MonthlyBill {
  const MonthlyBillModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.floorId,
    required super.unitId,
    required super.tenantId,
    super.tenantUserId,
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

  factory MonthlyBillModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'Monthly bill document ${doc.id} has no data.',
      );
    }

    return MonthlyBillModel(
      id: doc.id,
      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),
      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),
      floorId: _readRequiredString(
        data,
        'floorId',
      ),
      unitId: _readRequiredString(
        data,
        'unitId',
      ),
      tenantId: _readRequiredString(
        data,
        'tenantId',
      ),
      tenantUserId: _readOptionalString(
        data,
        'tenantUserId',
      ),
      sourceRuleId: _readRequiredString(
        data,
        'sourceRuleId',
      ),
      type: _readBillType(data),
      valueType: _readBillValueType(data),
      amount: _readRequiredDouble(
        data,
        'amount',
      ),
      paidAmount: _readRequiredDouble(
        data,
        'paidAmount',
      ),
      billingPeriodStart: _readRequiredDateTime(
        data,
        'billingPeriodStart',
      ),
      billingPeriodEnd: _readRequiredDateTime(
        data,
        'billingPeriodEnd',
      ),
      dueDate: _readRequiredDateTime(
        data,
        'dueDate',
      ),
      status: _readBillStatus(data),
      createdAt: _readRequiredDateTime(
        data,
        'createdAt',
      ),
      updatedAt: _readRequiredDateTime(
        data,
        'updatedAt',
      ),
    );
  }

  // ==========================================================================
  // TO FIRESTORE
  // ==========================================================================

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'propertyId': propertyId,
      'floorId': floorId,
      'unitId': unitId,
      'tenantId': tenantId,
      'tenantUserId': tenantUserId,
      'sourceRuleId': sourceRuleId,
      'type': type.name,
      'valueType': valueType.name,
      'amount': amount,
      'paidAmount': paidAmount,
      'billingPeriodStart':
      Timestamp.fromDate(billingPeriodStart),
      'billingPeriodEnd':
      Timestamp.fromDate(billingPeriodEnd),
      'dueDate':
      Timestamp.fromDate(dueDate),
      'status': status.name,
      'createdAt':
      Timestamp.fromDate(createdAt),
      'updatedAt':
      Timestamp.fromDate(updatedAt),
    };
  }

  // ==========================================================================
  // COPY WITH MODEL
  // ==========================================================================

  MonthlyBillModel copyWithModel({
    String? id,
    String? ownerId,
    String? propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
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
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      floorId: floorId ?? this.floorId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId: clearTenantUserId
          ? null
          : tenantUserId ?? this.tenantUserId,
      sourceRuleId:
      sourceRuleId ?? this.sourceRuleId,
      type: type ?? this.type,
      valueType:
      valueType ?? this.valueType,
      amount: amount ?? this.amount,
      paidAmount:
      paidAmount ?? this.paidAmount,
      billingPeriodStart:
      billingPeriodStart ??
          this.billingPeriodStart,
      billingPeriodEnd:
      billingPeriodEnd ??
          this.billingPeriodEnd,
      dueDate:
      dueDate ?? this.dueDate,
      status:
      status ?? this.status,
      createdAt:
      createdAt ?? this.createdAt,
      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }

  // ==========================================================================
  // READ HELPERS
  // ==========================================================================

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String ||
        value.trim().isEmpty) {
      throw StateError(
        'Monthly bill field "$field" '
            'is missing or invalid.',
      );
    }

    return value.trim();
  }

  static String? _readOptionalString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError(
        'Monthly bill field "$field" '
            'is invalid.',
      );
    }

    final normalized = value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }

  static double _readRequiredDouble(
      Map<String, dynamic> data,
      String field,
      ) {
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

  static DateTime _readRequiredDateTime(
      Map<String, dynamic> data,
      String field,
      ) {
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

  static MonthlyBillType _readBillType(
      Map<String, dynamic> data,
      ) {
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
        throw StateError(
          'Unknown monthly bill type: $value',
        );
      },
    );
  }

  // ==========================================================================
  // BILL VALUE TYPE
  // ==========================================================================

  static BillingValueType _readBillValueType(
      Map<String, dynamic> data,
      ) {
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
        throw StateError(
          'Unknown billing value type: $value',
        );
      },
    );
  }

  // ==========================================================================
  // BILL STATUS
  // ==========================================================================

  static MonthlyBillStatus _readBillStatus(
      Map<String, dynamic> data,
      ) {
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
        throw StateError(
          'Unknown monthly bill status: $value',
        );
      },
    );
  }
}