import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rent_rate.dart';

class RentRateModel extends RentRate {
  const RentRateModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.unitId,
    required super.amount,
    required super.effectiveFrom,
    super.effectiveTo,
    required super.source,
    super.previousRentRateId,
    super.nextRentRateId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory RentRateModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'Rent rate document ${doc.id} has no data.',
      );
    }

    return RentRateModel(
      id: doc.id,
      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),
      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),
      unitId: _readRequiredString(
        data,
        'unitId',
      ),
      amount: _readRequiredDouble(
        data,
        'amount',
      ),
      effectiveFrom: _readRequiredDateTime(
        data,
        'effectiveFrom',
      ),
      effectiveTo: _readOptionalDateTime(
        data,
        'effectiveTo',
      ),
      source: _readSource(data),
      previousRentRateId: _readOptionalString(
        data,
        'previousRentRateId',
      ),
      nextRentRateId: _readOptionalString(
        data,
        'nextRentRateId',
      ),
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
      'amount': amount,
      'effectiveFrom': Timestamp.fromDate(
        effectiveFrom,
      ),
      'effectiveTo': effectiveTo == null
          ? null
          : Timestamp.fromDate(
        effectiveTo!,
      ),
      'source': source.name,
      'previousRentRateId': previousRentRateId,
      'nextRentRateId': nextRentRateId,
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
        'Rent rate field "$field" is missing or invalid.',
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
        'Rent rate field "$field" is invalid.',
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

    if (value is num) {
      final result = value.toDouble();

      if (result <= 0) {
        throw StateError(
          'Rent rate field "$field" must be greater than zero.',
        );
      }

      return result;
    }

    throw StateError(
      'Rent rate field "$field" is missing or invalid.',
    );
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
      'Rent rate field "$field" is missing or invalid.',
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
      'Rent rate field "$field" is invalid.',
    );
  }

  static RentRateSource _readSource(
      Map<String, dynamic> data,
      ) {
    final value = data['source'];

    if (value is! String) {
      throw StateError(
        'Rent rate field "source" is missing or invalid.',
      );
    }

    return RentRateSource.values.firstWhere(
          (source) => source.name == value,
      orElse: () {
        throw StateError(
          'Unknown rent rate source: $value',
        );
      },
    );
  }
}