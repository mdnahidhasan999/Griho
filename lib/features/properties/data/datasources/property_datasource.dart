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
    final document = await _properties.doc(propertyId).get();

    if (!document.exists) {
      return null;
    }

    return PropertyModel.fromFirestore(document);
  }

  // ============================================================
  // GET PROPERTIES BY OWNER
  // ============================================================

  Future<List<PropertyModel>> getPropertiesByOwnerId(String ownerId) async {
    final snapshot = await _properties
        .where('ownerId', isEqualTo: ownerId)
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
    if (numberOfFloors < 1) {
      throw ArgumentError('Number of floors must be at least 1.');
    }

    final document = _properties.doc();

    final propertyCode = await _generatePropertyCode(ownerId: ownerId);

    final now = DateTime.now();

    final property = PropertyModel(
      id: document.id,
      propertyCode: propertyCode,
      ownerId: ownerId,
      name: name,
      address: address,
      description: description,
      type: type,
      status: PropertyStatus.active,
      numberOfFloors: numberOfFloors,
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

    final document = _properties.doc(property.id);

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
    await _properties.doc(propertyId).delete();
  }

  // ============================================================
  // GENERATE PROPERTY CODE
  // ============================================================

  Future<String> _generatePropertyCode({required String ownerId}) async {
    final snapshot = await _properties
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'PROP-0001';
    }

    final latest = PropertyModel.fromFirestore(snapshot.docs.first);

    final match = RegExp(r'(\d+)$').firstMatch(latest.propertyCode);

    if (match == null) {
      return 'PROP-0001';
    }

    final latestNumber = int.tryParse(match.group(1)!) ?? 0;

    final nextNumber = latestNumber + 1;

    return 'PROP-${nextNumber.toString().padLeft(4, '0')}';
  }
}
