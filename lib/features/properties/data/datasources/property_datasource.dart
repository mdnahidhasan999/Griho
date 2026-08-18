import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/property.dart';
import '../models/property_model.dart';

class PropertyDataSource {
  final FirebaseFirestore _firestore;

  PropertyDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'properties';

  CollectionReference<Map<String, dynamic>> get _properties =>
      _firestore.collection(_collectionName);

  Future<PropertyModel?> getPropertyById(
      String propertyId,
      ) async {
    final document = await _properties.doc(propertyId).get();

    if (!document.exists) {
      return null;
    }

    return PropertyModel.fromFirestore(document);
  }

  Future<List<PropertyModel>> getPropertiesByOwnerId(
      String ownerId,
      ) async {
    final snapshot = await _properties
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(PropertyModel.fromFirestore)
        .toList();
  }

  Future<PropertyModel> createProperty({
    required String ownerId,
    required String name,
    String? address,
    String? description,
    required PropertyType type,
  }) async {
    final document = _properties.doc();

    final now = DateTime.now();

    final property = PropertyModel(
      id: document.id,
      ownerId: ownerId,
      name: name,
      address: address,
      description: description,
      type: type,
      status: PropertyStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(
      property.toFirestore(),
    );

    return property;
  }

  Future<PropertyModel> updateProperty(
      PropertyModel property,
      ) async {
    final document = _properties.doc(property.id);

    await document.update(
      property.toFirestore(),
    );

    final updatedDocument = await document.get();

    if (!updatedDocument.exists) {
      throw StateError(
        'Property was updated but could not be retrieved.',
      );
    }

    return PropertyModel.fromFirestore(
      updatedDocument,
    );
  }

  Future<void> deleteProperty(
      String propertyId,
      ) async {
    await _properties.doc(propertyId).delete();
  }
}