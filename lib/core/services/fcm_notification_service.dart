import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint(
      '[FCM Background] ${message.messageId}: ${message.notification?.title}',
    );
  }
}

class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'griho_high_importance',
    'Griho Important Alerts',
    description: 'Notifications for bills, payments, invitations, and notices.',
    importance: Importance.high,
  );

  /// Initialize push notifications & register current user's FCM token.
  Future<void> initialize({void Function(String route)? onNavigate}) async {
    if (_initialized) {
      await syncTokenForCurrentUser();
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 1. Request permission (Android 13+, iOS, Web)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Setup local notifications for foreground display (non-web)
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          final route = details.payload?.trim();
          if (route != null && route.isNotEmpty && onNavigate != null) {
            onNavigate(route);
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 3. Foreground message listener
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      _showForegroundBanner(message);
    });

    // 4. Background -> Opened app tap listener
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = (message.data['route'] ?? '').toString().trim();
      if (route.isNotEmpty && onNavigate != null) {
        onNavigate(route);
      }
    });

    // 5. Terminated state -> Opened via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final route = (initialMessage.data['route'] ?? '').toString().trim();
      if (route.isNotEmpty && onNavigate != null) {
        onNavigate(route);
      }
    }

    // 6. Save token & listen for token rotation
    await syncTokenForCurrentUser();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });

    _initialized = true;
  }

  /// Sync current device token to users/{uid}.fcmTokens
  Future<void> syncTokenForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _saveTokenToFirestore(token.trim());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Could not sync token: $e');
      }
    }
  }

  /// Remove current device token on logout so user stops receiving alerts
  Future<void> removeTokenOnLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await _messaging.getToken();
      if (user != null && token != null && token.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fcmTokens': FieldValue.arrayRemove([token.trim()]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (_) {}
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snap = await userRef.get();
    if (!snap.exists) return;

    final existing = List<String>.from(snap.data()?['fcmTokens'] ?? const []);
    if (existing.contains(token)) return;

    // Keep max 10 tokens per user (aligned with firestore.rules)
    if (existing.length >= 10) {
      final trimmed = [...existing.skip(existing.length - 9), token];
      await userRef.update({
        'fcmTokens': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _showForegroundBanner(RemoteMessage message) async {
    if (kIsWeb) return;
    final notification = message.notification;
    if (notification == null) return;

    final route = (message.data['route'] ?? '').toString();

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Griho',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
  }
}
