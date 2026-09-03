import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging, with graceful degradation.
///
/// Push needs `android/app/google-services.json`, downloaded from the Firebase
/// console after registering the Android app in the `replit-pasay` project. That
/// file is gitignored (it identifies a specific Firebase app), so a fresh clone
/// will not have it.
///
/// Rather than crash or fail the build, every method here becomes a no-op when
/// Firebase is unavailable and [isAvailable] reports false. The in-app inbox
/// still shows every alert and Report/Ignore still works — the backend writes
/// both, so the only thing lost without push is the interruption itself. This
/// mirrors the backend's own `*_configured` pattern.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _available = false;
  bool get isAvailable => _available;

  /// Set when a notification tap opened the app, so the UI can route to the
  /// relevant area once it has built.
  String? pendingAreaId;

  final _messages = StreamController<RemoteMessage>.broadcast();

  /// Alerts arriving while the app is in the foreground.
  Stream<RemoteMessage> get onMessage => _messages.stream;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      // Missing google-services.json, or a Firebase project misconfiguration.
      debugPrint('Push disabled: $error');
      _available = false;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ requires runtime permission; earlier versions grant it at
      // install. A refusal is a normal outcome, not an error.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_messages.add);

      // Tapped from the notification tray with the app backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        pendingAreaId = message.data['area_id'] as String?;
        _messages.add(message);
      });

      // Tapped while the app was terminated — delivered once at startup.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        pendingAreaId = initial.data['area_id'] as String?;
      }
    } catch (error) {
      debugPrint('Push setup incomplete: $error');
    }
  }

  /// The device token to register with the backend, or null when unavailable.
  Future<String?> token() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Could not read FCM token: $error');
      return null;
    }
  }

  /// Fires when FCM rotates the token, which it does periodically and after a
  /// reinstall. Without re-registering, pushes silently stop reaching the device.
  Stream<String> get onTokenRefresh =>
      _available ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();
}
