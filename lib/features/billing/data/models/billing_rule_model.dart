import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';

class BillingRuleModel extends BillingRule {
  const BillingRuleModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.scopeType,
    required super.scopeId,
    required super.chargeType,
    required super.valueType,
    required super.amount,
    super.title,
    required super.effectiveFrom,
    super.effectiveTo,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BillingRuleModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'Billing rule document ${doc.id} has no data.',
      );
    }

    return BillingRuleModel(
      id: doc.id,
      ownerId: _readRequiredString(data, 'ownerId'),
      propertyId: _readRequiredString(data, 'propertyId'),
      scopeType: _readScopeType(data),
      scopeId: _readRequiredString(data, 'scopeId'),
      chargeType: _readChargeType(data),
      valueType: _readValueType(data),
      amount: _readOptionalDouble(data, 'amount'),
      title: _readOptionalString(data, 'title'),
      effectiveFrom: _readRequiredDateTime(
        data,
        'effectiveFrom',
      ),
      effectiveTo: _readOptionalDateTime(
        data,
        'effectiveTo',
      ),
      isActive: _readRequiredBool(data, 'isActive'),
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

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'propertyId': propertyId,
      'scopeType': scopeType.name,
      'scopeId': scopeId,
      'chargeType': chargeType.name,
      'valueType': valueType.name,
      'amount': amount,
      'title': title,
      'effectiveFrom': Timestamp.fromDate(
        effectiveFrom,
      ),
      'effectiveTo': effectiveTo == null
          ? null
          : Timestamp.fromDate(
        effectiveTo!,
      ),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(
        createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ),
    };
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Billing rule field "$field" is missing or invalid.',
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
        'Billing rule field "$field" is invalid.',
      );
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static double? _readOptionalDouble(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! num) {
      throw StateError(
        'Billing rule field "$field" is invalid.',
      );
    }

    final result = value.toDouble();

    if (result < 0) {
      throw StateError(
        'Billing rule field "$field" cannot be negative.',
      );
    }

    return result;
  }

  static bool _readRequiredBool(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! bool) {
      throw StateError(
        'Billing rule field "$field" is missing or invalid.',
      );
    }

    return value;
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
      'Billing rule field "$field" is missing or invalid.',
    );
  }

  static DateTime? _readOptionalDateTime(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError(
      'Billing rule field "$field" is invalid.',
    );
  }

  static BillingScopeType _readScopeType(
      Map<String, dynamic> data,
      ) {
    final value = data['scopeType'];

    if (value is! String) {
      throw StateError(
        'Billing rule field "scopeType" is missing or invalid.',
      );
    }

    return BillingScopeType.values.firstWhere(
          (scope) => scope.name == value,
      orElse: () {
        throw StateError(
          'Unknown billing scope type: $value',
        );
      },
    );
  }

  static BillingChargeType _readChargeType(
      Map<String, dynamic> data,
      ) {
    final value = data['chargeType'];

    if (value is! String) {
      throw StateError(
        'Billing rule field "chargeType" is missing or invalid.',
      );
    }

    return BillingChargeType.values.firstWhere(
          (type) => type.name == value,
      orElse: () {
        throw StateError(
          'Unknown billing charge type: $value',
        );
      },
    );
  }

  static BillingValueType _readValueType(
      Map<String, dynamic> data,
      ) {
    final value = data['valueType'];

    if (value is! String) {
      throw StateError(
        'Billing rule field "valueType" is missing or invalid.',
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
}