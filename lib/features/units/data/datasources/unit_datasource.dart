import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/create_unit_request.dart';
import '../../domain/entities/unit.dart';
import '../models/unit_model.dart';

class UnitDataSource {
  final FirebaseFirestore _firestore;

  UnitDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'units';

  CollectionReference<Map<String, dynamic>>
  get _units =>
      _firestore.collection(_collectionName);

  Future<UnitModel?> getUnitById(
      String unitId,
      ) async {
    final document =
    await _units.doc(unitId).get();

    if (!document.exists) {
      return null;
    }

    return UnitModel.fromFirestore(
      document,
    );
  }

  Future<List<UnitModel>> getUnitsByPropertyId(
      String propertyId,
      ) async {
    final snapshot = await _units
        .where(
      'propertyId',
      isEqualTo: propertyId,
    )
        .orderBy(
      'floorNumber',
    )
        .orderBy(
      'unitNumber',
    )
        .get();

    return snapshot.docs
        .map(UnitModel.fromFirestore)
        .toList();
  }

  Future<UnitModel> createUnit({
    required CreateUnitRequest request,
  }) async {
    if (request.floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (request.unitNumber.trim().isEmpty) {
      throw ArgumentError(
        'Unit number cannot be empty.',
      );
    }

    if (request.monthlyRent != null &&
        request.monthlyRent! < 0) {
      throw ArgumentError(
        'Monthly rent cannot be negative.',
      );
    }

    final document = _units.doc();

    final now = DateTime.now();

    final unit = UnitModel(
      id: document.id,
      propertyId: request.propertyId,
      floorNumber: request.floorNumber,
      unitNumber: request.unitNumber.trim(),
      name: request.name?.trim().isEmpty == true
          ? null
          : request.name?.trim(),
      status: UnitStatus.available,
      monthlyRent: request.monthlyRent,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(
      unit.toFirestore(),
    );

    return unit;
  }

  Future<UnitModel> updateUnit(
      UnitModel unit,
      ) async {
    if (unit.floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (unit.unitNumber.trim().isEmpty) {
      throw ArgumentError(
        'Unit number cannot be empty.',
      );
    }

    if (unit.monthlyRent != null &&
        unit.monthlyRent! < 0) {
      throw ArgumentError(
        'Monthly rent cannot be negative.',
      );
    }

    final document =
    _units.doc(unit.id);

    await document.update(
      unit.toFirestore(),
    );

    final updatedDocument =
    await document.get();

    if (!updatedDocument.exists) {
      throw StateError(
        'Unit was updated but could not be retrieved.',
      );
    }

    return UnitModel.fromFirestore(
      updatedDocument,
    );
  }

  Future<void> deleteUnit(
      String unitId,
      ) async {
    await _units.doc(unitId).delete();
  }
}