import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.publicId,
    required super.role,
    required super.name,
    super.phoneNumber,
    super.email,
    super.photoUrl,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AppUserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError('User document does not exist.');
    }

    return AppUserModel(
      uid: data['uid'] as String,
      publicId: data['publicId'] as String,
      role: _roleFromString(data['role'] as String),
      name: data['name'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateTimeFromTimestamp(data['createdAt']),
      updatedAt: _dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'publicId': publicId,
      'role': role.name,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static UserRole _roleFromString(String value) {
    return UserRole.values.firstWhere(
          (role) => role.name == value,
      orElse: () => throw StateError('Invalid user role: $value'),
    );
  }

  static DateTime _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError('Invalid timestamp value.');
  }
  factory AppUserModel.fromEntity(AppUser user) {
    return AppUserModel(
      uid: user.uid,
      publicId: user.publicId,
      role: user.role,
      name: user.name,
      phoneNumber: user.phoneNumber,
      email: user.email,
      photoUrl: user.photoUrl,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}