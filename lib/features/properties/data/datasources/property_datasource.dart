import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/property.dart';
import '../models/property_model.dart';

class PropertyDataSource {
  final FirebaseFirestore _firestore;

  PropertyDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'properties';

  CollectionReference<Map<String, dynamic>> get _properties =>
      _firestore.collection(_collectionName);

  // ============================================================
  // GET PROPERTY BY FIRESTORE ID
  // ============================================================

  Future<PropertyModel?> getPropertyById(String propertyId) async {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      return null;
    }

    final document = await _properties.doc(normalizedPropertyId).get();

    if (!document.exists) {
      return null;
    }

    return PropertyModel.fromFirestore(document);
  }

  // ============================================================
  // GET PROPERTIES BY OWNER
  // ============================================================

  Future<List<PropertyModel>> getPropertiesByOwnerId(String ownerId) async {
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _properties
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(PropertyModel.fromFirestore).toList();
  }

  // ============================================================
  // CREATE PROPERTY
  // ============================================================

  Future<PropertyModel> createProperty({
    required String ownerId,
    required String name,
    String? address,
    String? description,
    required PropertyType type,
    required int numberOfFloors,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedName = name.trim();
    final normalizedAddress = address?.trim();
    final normalizedDescription = description?.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('Property name cannot be empty.');
    }

    if (numberOfFloors < 1) {
      throw ArgumentError('Number of floors must be at least 1.');
    }

    final document = _properties.doc();

    final propertyCode = await _generatePropertyCode(
      ownerId: normalizedOwnerId,
    );

    final now = DateTime.now();

    final property = PropertyModel(
      id: document.id,
      propertyCode: propertyCode,
      ownerId: normalizedOwnerId,
      name: normalizedName,
      address: normalizedAddress?.isEmpty == true
          ? null
          : normalizedAddress,
      description: normalizedDescription?.isEmpty == true
          ? null
          : normalizedDescription,
      type: type,
      status: PropertyStatus.active,
      numberOfFloors: numberOfFloors,
      tenantUserIds: const [],
      createdAt: now,
      updatedAt: now,
    );

    await document.set(property.toFirestore());

    return property;
  }

  // ============================================================
  // UPDATE PROPERTY
  // ============================================================

  Future<PropertyModel> updateProperty(PropertyModel property) async {
    if (property.numberOfFloors < 1) {
      throw ArgumentError('Number of floors must be at least 1.');
    }

    final propertyId = property.id.trim();

    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    final document = _properties.doc(propertyId);

    await document.update(property.toFirestore());

    final updatedDocument = await document.get();

    if (!updatedDocument.exists) {
      throw StateError('Property was updated but could not be retrieved.');
    }

    return PropertyModel.fromFirestore(updatedDocument);
  }

  // ============================================================
  // DELETE PROPERTY
  // ============================================================

  Future<void> deleteProperty(String propertyId) async {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      return;
    }

    await _properties.doc(normalizedPropertyId).delete();
  }

  // ============================================================
  // ADD TENANT USER TO PROPERTY
  // ============================================================
  //
  // Adds a linked tenant Firebase UID to the property's
  // access-control list.
  //
  // This UID is internal security data.
  // It must never be displayed directly in the UI.
  // ============================================================

  Future<void> addTenantUserToProperty({
    required String propertyId,
    required String tenantUserId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedTenantUserId = tenantUserId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedTenantUserId.isEmpty) {
      throw ArgumentError('Tenant user ID cannot be empty.');
    }

    await _properties.doc(normalizedPropertyId).update({
      'tenantUserIds': FieldValue.arrayUnion([
        normalizedTenantUserId,
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // REMOVE TENANT USER FROM PROPERTY
  // ============================================================
  //
  // Removes a linked tenant Firebase UID from the property's
  // access-control list.
  // ============================================================

  Future<void> removeTenantUserFromProperty({
    required String propertyId,
    required String tenantUserId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedTenantUserId = tenantUserId.trim();

    if (normalizedPropertyId.isEmpty) {
      return;
    }

    if (normalizedTenantUserId.isEmpty) {
      return;
    }

    await _properties.doc(normalizedPropertyId).update({
      'tenantUserIds': FieldValue.arrayRemove([
        normalizedTenantUserId,
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GENERATE PROPERTY CODE
  // ============================================================

  Future<String> _generatePropertyCode({
    required String ownerId,
  }) async {
    final normalizedOwnerId = ownerId.trim();

    final snapshot = await _properties
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'PROP-0001';
    }

    final latest = PropertyModel.fromFirestore(
      snapshot.docs.first,
    );

    final match = RegExp(
      r'(\d+)$',
    ).firstMatch(
      latest.propertyCode,
    );

    if (match == null) {
      return 'PROP-0001';
    }

    final latestNumber = int.tryParse(
      match.group(1)!,
    ) ??
        0;

    final nextNumber = latestNumber + 1;

    return 'PROP-${nextNumber.toString().padLeft(4, '0')}';
  }
}