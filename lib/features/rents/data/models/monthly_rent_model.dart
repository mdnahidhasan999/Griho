import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/monthly_rent.dart';

class MonthlyRentModel extends MonthlyRent {
  const MonthlyRentModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.unitId,
    required super.tenantId,
    super.tenantUserId,
    required super.rentRateId,
    required super.monthlyRate,
    required super.amount,
    required super.chargeableDays,
    required super.daysInBillingPeriod,
    required super.prorationFactor,
    required super.billingPeriodStart,
    required super.billingPeriodEnd,
    required super.chargePeriodStart,
    required super.chargePeriodEnd,
    required super.dueDate,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory MonthlyRentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'Monthly rent document ${doc.id} has no data.',
      );
    }

    return MonthlyRentModel(
      id: doc.id,
      ownerId: _readRequiredString(data, 'ownerId'),
      propertyId: _readRequiredString(data, 'propertyId'),
      unitId: _readRequiredString(data, 'unitId'),
      tenantId: _readRequiredString(data, 'tenantId'),
      tenantUserId: _readOptionalString(data, 'tenantUserId'),
      rentRateId: _readRequiredString(data, 'rentRateId'),
      monthlyRate: _readRequiredDouble(
        data,
        'monthlyRate',
      ),
      amount: _readRequiredDouble(
        data,
        'amount',
      ),
      chargeableDays: _readRequiredPositiveInt(
        data,
        'chargeableDays',
      ),
      daysInBillingPeriod: _readRequiredPositiveInt(
        data,
        'daysInBillingPeriod',
      ),
      prorationFactor: _readRequiredPositiveDouble(
        data,
        'prorationFactor',
      ),
      billingPeriodStart: _readRequiredDateTime(
        data,
        'billingPeriodStart',
      ),
      billingPeriodEnd: _readRequiredDateTime(
        data,
        'billingPeriodEnd',
      ),
      chargePeriodStart: _readRequiredDateTime(
        data,
        'chargePeriodStart',
      ),
      chargePeriodEnd: _readRequiredDateTime(
        data,
        'chargePeriodEnd',
      ),
      dueDate: _readRequiredDateTime(
        data,
        'dueDate',
      ),
      status: _readStatus(data),
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
      'unitId': unitId,
      'tenantId': tenantId,
      'tenantUserId': tenantUserId,
      'rentRateId': rentRateId,
      'monthlyRate': monthlyRate,
      'amount': amount,
      'chargeableDays': chargeableDays,
      'daysInBillingPeriod': daysInBillingPeriod,
      'prorationFactor': prorationFactor,
      'billingPeriodStart':
      Timestamp.fromDate(billingPeriodStart),
      'billingPeriodEnd':
      Timestamp.fromDate(billingPeriodEnd),
      'chargePeriodStart':
      Timestamp.fromDate(chargePeriodStart),
      'chargePeriodEnd':
      Timestamp.fromDate(chargePeriodEnd),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
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

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError(
        'Monthly rent field "$field" is invalid.',
      );
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static double _readRequiredDouble(
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

    if (result <= 0) {
      throw StateError(
        'Monthly rent field "$field" must be greater than zero.',
      );
    }

    return result;
  }

  static double _readRequiredPositiveDouble(
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

    if (result <= 0) {
      throw StateError(
        'Monthly rent field "$field" must be greater than zero.',
      );
    }

    return result;
  }

  static int _readRequiredPositiveInt(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! num || value % 1 != 0) {
      throw StateError(
        'Monthly rent field "$field" is missing or invalid.',
      );
    }

    final result = value.toInt();

    if (result <= 0) {
      throw StateError(
        'Monthly rent field "$field" must be greater than zero.',
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
      'Monthly rent field "$field" is missing or invalid.',
    );
  }

  static MonthlyRentStatus _readStatus(
      Map<String, dynamic> data,
      ) {
    final value = data['status'];

    if (value is! String) {
      throw StateError(
        'Monthly rent field "status" is missing or invalid.',
      );
    }

    return MonthlyRentStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () => throw StateError(
        'Unknown monthly rent status: $value',
      ),
    );
  }
}