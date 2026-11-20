import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../utils/image_compression_helper.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// 1. Upload User Profile Avatar
  /// Matches storage.rules: /users/{userId}/profile/{fileName}
  Future<String> uploadUserProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    final normalizedUid = userId.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'users/$normalizedUid/profile/$fileName';
    return _compressAndUpload(storagePath: path, rawFile: imageFile);
  }

  /// 2. Upload Tenant Photo or NID Image
  /// Matches storage.rules: /properties/{propertyId}/tenants/{tenantId}/{fileName}
  Future<String> uploadTenantDocument({
    required String propertyId,
    required String tenantId,
    required String docType, // e.g., 'photo', 'nid_front', 'nid_back'
    required File imageFile,
  }) async {
    final normalizedPropId = propertyId.trim();
    final normalizedTenantId = tenantId.trim();
    if (normalizedPropId.isEmpty || normalizedTenantId.isEmpty) {
      throw ArgumentError('Property ID and Tenant ID are required.');
    }

    final safeType = docType.trim().isEmpty ? 'doc' : docType.trim();
    final fileName = '${safeType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path =
        'properties/$normalizedPropId/tenants/$normalizedTenantId/$fileName';
    return _compressAndUpload(storagePath: path, rawFile: imageFile);
  }

  /// 3. Upload Payment Proof / Screenshot
  /// Matches storage.rules: /properties/{propertyId}/payments/{paymentId}/{fileName}
  Future<String> uploadPaymentProof({
    required String propertyId,
    required String paymentId,
    required File imageFile,
  }) async {
    final normalizedPropId = propertyId.trim();
    final normalizedPaymentId = paymentId.trim();
    if (normalizedPropId.isEmpty || normalizedPaymentId.isEmpty) {
      throw ArgumentError('Property ID and Payment ID are required.');
    }

    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path =
        'properties/$normalizedPropId/payments/$normalizedPaymentId/$fileName';
    return _compressAndUpload(storagePath: path, rawFile: imageFile);
  }

  /// Safely delete an old image using its download URL
  Future<void> deleteFileByUrl(String? url) async {
    final normalizedUrl = url?.trim() ?? '';
    if (normalizedUrl.isEmpty || !normalizedUrl.startsWith('http')) return;
    try {
      await _storage.refFromURL(normalizedUrl).delete();
    } catch (_) {
      // Ignore if file already deleted or external URL (e.g., Google avatar)
    }
  }

  Future<String> _compressAndUpload({
    required String storagePath,
    required File rawFile,
  }) async {
    final compressed = await ImageCompressionHelper.compressImage(rawFile);
    final fileToUpload = compressed ?? rawFile;

    final int sizeBytes = await fileToUpload.length();
    if (sizeBytes > 5 * 1024 * 1024) {
      throw StateError('Image exceeds the 5 MB limit even after compression.');
    }

    try {
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final taskSnapshot = await ref.putFile(fileToUpload, metadata);
      return await taskSnapshot.ref.getDownloadURL();
    } finally {
      // Clean up temporary compressed file
      if (compressed != null &&
          compressed.path != rawFile.path &&
          await compressed.exists()) {
        try {
          await compressed.delete();
        } catch (_) {}
      }
    }
  }
}
