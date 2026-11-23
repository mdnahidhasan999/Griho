import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.publicId,
    required super.name,
    super.phoneNumber,
    super.email,
    super.photoUrl,
    super.nidNumber,
    super.dateOfBirth,
    super.occupation,
    super.gender,
    super.maritalStatus,
    super.nidFrontUrl,
    super.nidBackUrl,
    super.defaultDashboard,
    super.availableRoles = const [],
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  static DateTime? _parseOptionalDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['availableRoles'];

    final roles = rawRoles is List
        ? rawRoles.whereType<String>().toSet().toList()
        : <String>[];

    return AppUserModel(
      uid: json['uid'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      nidNumber: json['nidNumber'] as String?,
      dateOfBirth: _parseOptionalDate(json['dateOfBirth']),
      occupation: json['occupation'] as String?,
      gender: json['gender'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      nidFrontUrl: json['nidFrontUrl'] as String?,
      nidBackUrl: json['nidBackUrl'] as String?,
      defaultDashboard: json['defaultDashboard'] as String?,
      availableRoles: List.unmodifiable(roles),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory AppUserModel.fromEntity(AppUser user) {
    return AppUserModel(
      uid: user.uid,
      publicId: user.publicId,
      name: user.name,
      phoneNumber: user.phoneNumber,
      email: user.email,
      photoUrl: user.photoUrl,
      nidNumber: user.nidNumber,
      dateOfBirth: user.dateOfBirth,
      occupation: user.occupation,
      gender: user.gender,
      maritalStatus: user.maritalStatus,
      nidFrontUrl: user.nidFrontUrl,
      nidBackUrl: user.nidBackUrl,
      defaultDashboard: user.defaultDashboard,
      availableRoles: List.unmodifiable(user.availableRoles),
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  factory AppUserModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : const <String, dynamic>{};

    return AppUserModel.fromJson({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'publicId': publicId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      if (nidNumber != null) 'nidNumber': nidNumber,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'occupation': occupation,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'nidFrontUrl': nidFrontUrl,
      'nidBackUrl': nidBackUrl,
      'defaultDashboard': defaultDashboard,
      'availableRoles': availableRoles,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }
}
