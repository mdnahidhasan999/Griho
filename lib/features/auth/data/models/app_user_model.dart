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
    super.defaultDashboard,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      uid: json['uid'] as String,
      publicId: json['publicId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      defaultDashboard: json['defaultDashboard'] as String?,
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
      defaultDashboard: user.defaultDashboard,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  factory AppUserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
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
      'defaultDashboard': defaultDashboard,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }
}
