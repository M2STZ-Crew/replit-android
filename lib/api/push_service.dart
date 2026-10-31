import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../sound/sound_cues.dart';
import '../theme.dart';
import 'api_client.dart';
import 'notification_router.dart';
import 'session.dart';

/// Background FCM handler — must be a top-level, entry-point function.
///
/// Notification-payload messages are shown by Android automatically while the
/// app is backgrounded/terminated — in the channel the server names, so a fire
/// rings with the fire alarm — so there's nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Owns the device's FCM lifecycle: registers the token with the backend
/// (POST /devices), pushes the user's location for 150 m neighborhood alerts,
/// surfaces foreground pushes in-app, and unregisters on logout.
///
/// v1.12.6: every push opens what it is about when tapped — in the shade, or
/// on the banner shown while the app is open ([NotificationRouter]).
///
/// v1.12.9: a push arriving while the app is open plays the recording it
/// names (`sound_category`), as its notification channel does while the app
/// is closed; a silent reminder only vibrates.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Lets foreground pushes show a SnackBar without a BuildContext.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Lets a tapped notification navigate / show a dialog without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _kEnabledKey = 'push_enabled';

  final ApiClient _api = ApiClient();
  String? _token;

  /// Sent with the device, so the server knows which build each phone runs.
  static String? get _version =>
      AppVersion.label.isEmpty ? null : AppVersion.label;
  bool _listenersReady = false;

  /// Whether the user has emergency alerts switched on (default true).
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? true;
  }

  /// Toggle alerts: registers (+ pushes location) or unregisters this device.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
    if (enabled) {
      await syncForUser();
    } else {
      await unregister();
    }
  }

  /// One-time listener setup — call once in main() after Firebase.initializeApp.
  void initListeners() {
    if (_listenersReady) return;
    _listenersReady = true;
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
    // App launched from a terminated state by tapping a notification.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      // Let the splash route to home first, then surface the alert.
      Future.delayed(
        const Duration(milliseconds: 1700),
        () => _onOpened(message),
      );
    });
  }

  /// After auth: request permission, register the token, and push location so
  /// this device can receive nearby-incident alerts. Best-effort and silent.
  Future<void> syncForUser() async {
    if (!Session.instance.isAuthenticated) return;
    if (!await isEnabled()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null) return;
      _token = token;
      await _api.registerDevice(
        fcmToken: token,
        deviceName: 'RepLiT Android',
        appVersion: _version,
      );
      await _pushLocation();
    } catch (_) {
      // FCM unconfigured / offline — push simply stays inactive.
    }
  }

  /// Re-send the current GPS so this user stays locatable for nearby-incident
  /// alerts (called on app resume). Best-effort and silent.
  Future<void> refreshLocation() async {
    if (!Session.instance.isAuthenticated) return;
    if (!await isEnabled()) return;
    await _pushLocation();
  }

  Future<void> _pushLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _api.updateMyLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    _token = token;
    if (!Session.instance.isAuthenticated) return;
    try {
      await _api.registerDevice(
        fcmToken: token,
        deviceName: 'RepLiT Android',
        appVersion: _version,
      );
    } catch (_) {
      // ignore
    }
  }

  void _onForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (message.data['silent'] == 'true') {
      unawaited(HapticFeedback.vibrate());
    } else {
      unawaited(
        SoundCues.instance.playAlert(message.data['sound_category'] as String?),
      );
    }
    // A fire near them, with the app open: straight to "Do you see it too?"
    // ("11 Corroborate", 150 m) — or, for staff, the incident.
    if (type == 'neighborhood_alert') {
      _onOpened(message);
      return;
    }
    final notification = message.notification;
    final title = notification?.title ?? 'RepLiT';
    final body = notification?.body ?? (message.data['body'] as String?) ?? '';
    if (body.isEmpty) return;
    messengerKey.currentState?.showSnackBar(
      inAppBanner(
        title: title,
        body: body,
        fire: fireAlertTypes.contains(type),
        onOpen: canOpen(type, message.data) ? () => _onOpened(message) : null,
        duration: type == 'test' ? testBannerFor : bannerFor,
      ),
    );
  }

  /// How long the in-app banner for a push stays up without a tap.
  static const Duration bannerFor = Duration(seconds: 10);

  /// A test alert is a check, not news, and has nothing to open.
  static const Duration testBannerFor = Duration(seconds: 4);

  /// The banner a push shows while the app is open ("Help is on the way",
  /// OPEN). It goes away by itself after [bannerFor] whether or not OPEN was
  /// tapped: a banner with an action would otherwise stay until tapped
  /// (Flutter keeps those by default). The Alerts list keeps every one.
  @visibleForTesting
  static SnackBar inAppBanner({
    required String title,
    required String body,
    required bool fire,
    VoidCallback? onOpen,
    Duration duration = bannerFor,
  }) {
    return SnackBar(
      backgroundColor: fire ? AppColors.live : AppColors.gradientEnd,
      duration: duration,
      persist: false,
      action: onOpen == null
          ? null
          : SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: onOpen,
            ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  /// A push was tapped — in the shade, or OPEN on the in-app banner. Opens
  /// what it is about for whoever is signed in ([NotificationRouter]): the
  /// incident for staff, "Do you see it too?" for a neighbour, the live
  /// tracker for the resident who reported it, the alarm queue for BFP.
  void _onOpened(RemoteMessage message) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    unawaited(
      NotificationRouter(
        api: _api,
      ).open(nav, type: message.data['type'] as String?, data: message.data),
    );
  }

  /// On logout: drop this device's token server-side (while still authenticated).
  Future<void> unregister() async {
    final token = _token ?? await _safeToken();
    if (token != null) await _api.unregisterDevice(token);
    _token = null;
  }

  Future<String?> _safeToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
