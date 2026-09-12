import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/create_unit_request.dart';
import '../../domain/entities/unit.dart';
import '../models/unit_model.dart';

class UnitDataSource {
  final FirebaseFirestore _firestore;

  UnitDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'units';

  CollectionReference<Map<String, dynamic>> get _units =>
      _firestore.collection(_collectionName);

  // ============================================================
  // GET UNIT BY ID
  // ============================================================

  Future<UnitModel?> getUnitById(String unitId,) async {
    final normalizedUnitId = unitId.trim();

    if (normalizedUnitId.isEmpty) {
      return null;
    }

    final document = await _units
        .doc(normalizedUnitId)
        .get();

    if (!document.exists) {
      return null;
    }

    return UnitModel.fromFirestore(document);
  }

  // ============================================================
  // GET UNITS BY PROPERTY
  // ============================================================

  Future<List<UnitModel>> getUnitsByPropertyId(String propertyId,) async {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      return [];
    }

    final snapshot = await _units
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .orderBy('floorNumber')
        .orderBy('unitNumber')
        .get();

    return snapshot.docs
        .map(UnitModel.fromFirestore)
        .toList();
  }

  // ============================================================
  // GET OCCUPIED UNITS BY PROPERTY
  // ============================================================

  Future<List<UnitModel>> getOccupiedUnitsByProperty({
    required String propertyId,
  }) async {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    final snapshot = await _units
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .where(
      'status',
      isEqualTo: UnitStatus.occupied.name,
    )
        .orderBy('floorNumber')
        .orderBy('unitNumber')
        .get();

    return snapshot.docs
        .map(UnitModel.fromFirestore)
        .toList();
  }

  // ============================================================
  // GET OCCUPIED UNITS BY FLOOR
  // ============================================================

  Future<List<UnitModel>> getOccupiedUnitsByFloor({
    required String propertyId,
    required int floorNumber,
  }) async {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    final snapshot = await _units
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .where(
      'floorNumber',
      isEqualTo: floorNumber,
    )
        .where(
      'status',
      isEqualTo: UnitStatus.occupied.name,
    )
        .orderBy('unitNumber')
        .get();

    return snapshot.docs
        .map(UnitModel.fromFirestore)
        .toList();
  }

  // ============================================================
  // CREATE UNIT
  // ============================================================

  Future<UnitModel> createUnit({
    required CreateUnitRequest request,
  }) async {
    final propertyId = request.propertyId.trim();
    final unitNumber = request.unitNumber.trim();

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (request.floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (unitNumber.isEmpty) {
      throw ArgumentError(
        'Unit number cannot be empty.',
      );
    }

    final document = _units.doc();
    final now = DateTime.now();

    final unit = UnitModel(
      id: document.id,
      propertyId: propertyId,
      floorNumber: request.floorNumber,
      unitNumber: unitNumber,
      name: request.name
          ?.trim()
          .isEmpty == true
          ? null
          : request.name?.trim(),
      status: UnitStatus.available,
      tenantUserId: null,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(
      unit.toFirestore(),
    );

    return unit;
  }

  // ============================================================
  // UPDATE UNIT
  // ============================================================

  Future<UnitModel> updateUnit(UnitModel unit,) async {
    final unitId = unit.id.trim();
    final propertyId = unit.propertyId.trim();
    final unitNumber = unit.unitNumber.trim();

    if (unitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (unit.floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (unitNumber.isEmpty) {
      throw ArgumentError(
        'Unit number cannot be empty.',
      );
    }

    final document = _units.doc(unitId);

    await document.update(
      unit.toFirestore(),
    );

    final updatedDocument = await document.get();

    if (!updatedDocument.exists) {
      throw StateError(
        'Unit was updated but could not be retrieved.',
      );
    }

    return UnitModel.fromFirestore(
      updatedDocument,
    );
  }

  // ============================================================
  // DELETE UNIT
  // ============================================================

  Future<void> deleteUnit(String unitId,) async {
    final normalizedUnitId = unitId.trim();

    if (normalizedUnitId.isEmpty) {
      return;
    }

    await _units
        .doc(normalizedUnitId)
        .delete();
  }

  // ============================================================
  // ASSIGN TENANT USER
  // ============================================================

  Future<void> assignTenantUser({
    required String unitId,
    required String tenantUserId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedTenantUserId = tenantUserId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedTenantUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    await _units.doc(normalizedUnitId).update({
      'tenantUserId': normalizedTenantUserId,
      'status': UnitStatus.occupied.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // REMOVE TENANT USER
  // ============================================================

  Future<void> removeTenantUser({
    required String unitId,
  }) async {
    final normalizedUnitId = unitId.trim();

    if (normalizedUnitId.isEmpty) {
      return;
    }

    await _units.doc(normalizedUnitId).update({
      'tenantUserId': null,
      'status': UnitStatus.available.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}