import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRouterRefresh extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  AuthRouterRefresh() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen(
          (_) {
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}