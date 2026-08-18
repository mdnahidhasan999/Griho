import 'package:firebase_auth/firebase_auth.dart';

class CurrentUserService {
  final FirebaseAuth _firebaseAuth;

  CurrentUserService({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  String get requiredUid {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'A Firebase authenticated user is required.',
      );
    }

    return user.uid;
  }
}