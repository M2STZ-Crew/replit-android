import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/live_update_screen.dart';
import '../screens/neighbour_alert_screen.dart';
import '../screens/responder/responder_incident_screen.dart';
import '../screens/subadmin/coordinator_nav.dart';
import '../theme.dart';
import 'api_client.dart';
import 'session.dart';

/// Background FCM handler — must be a top-level, entry-point function.
///
/// Notification-payload messages are shown by Android automatically while the
/// app is backgrounded/terminated, so there's nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Owns the device's FCM lifecycle: registers the token with the backend
/// (POST /devices), pushes the user's location for 300 m neighborhood alerts,
/// surfaces foreground pushes in-app, and unregisters on logout.
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
        appVersion: '1.0.0',
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
        appVersion: '1.0.0',
      );
    } catch (_) {
      // ignore
    }
  }

  void _onForeground(RemoteMessage message) {
    if (message.data['type'] == 'neighborhood_alert') {
      _handleNeighborhood(message);
      return;
    }
    final notification = message.notification;
    final title = notification?.title ?? 'RepLiT';
    final body = notification?.body ?? (message.data['body'] as String?) ?? '';
    if (body.isEmpty) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.gradientEnd,
        duration: const Duration(seconds: 5),
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
      ),
    );
  }

  void _onOpened(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'neighborhood_alert') {
      _handleNeighborhood(message);
    } else if (type == 'incident_update') {
      final areaId = message.data['area_id'] as String?;
      if (areaId != null) _openIncident(areaId);
    } else if (type == 'responder_dispatch') {
      final areaId = message.data['area_id'] as String?;
      if (areaId != null) _openDispatch(areaId);
    } else if (type == 'incident_routed') {
      final areaId = message.data['area_id'] as String?;
      if (areaId != null) _openRouted(areaId);
    }
  }

  /// Admin routed an incident to this team captain's team (v10 §2.6.2):
  /// open it where a coordinator acts on it. Observer captains work from the
  /// web console, so the phone has nothing to open for them.
  Future<void> _openRouted(String areaId) async {
    try {
      final me = await _api.getMe();
      final coordinator =
          me['role'] == 'sub_admin' &&
          const {'fire_volunteer', 'bfp'}.contains(me['agency_type']);
      if (!coordinator) return;
      final incident = await _api.getIncident(areaId);
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await openCoordinatorIncident(ctx, incident: incident, me: me, api: _api);
    } catch (_) {
      // ignore — best-effort deep link; the incident is on the dashboard too
    }
  }

  /// A coordinator dispatched this responder: tapping the push opens the
  /// incident, where En route and Arrived are — and where location sharing
  /// starts, if the dashboard has not already picked the dispatch up.
  Future<void> _openDispatch(String areaId) async {
    try {
      final me = await _api.getMe();
      if (me['role'] != 'response_team') return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResponderIncidentScreen(
            incidentId: areaId,
            myId: me['id'] as String? ?? '',
            agency: me['agency_type'] as String?,
            orgId: me['primary_org_id'] as String?,
          ),
        ),
      );
    } catch (_) {
      // ignore — best-effort deep link; the dispatch is on the dashboard too
    }
  }

  /// Open the live tracker for an incident the citizen reported (tapped from a
  /// lifecycle push). Resolves the area's centroid to seed the map.
  Future<void> _openIncident(String areaId) async {
    try {
      final area = await _api.getArea(areaId);
      final lat = (area['centroid_lat'] as num?)?.toDouble();
      final lng = (area['centroid_lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveUpdateScreen(areaId: areaId, lat: lat, lng: lng),
        ),
      );
    } catch (_) {
      // ignore — best-effort deep link
    }
  }

  /// A 300 m neighbourhood alert opens "Do you see it too?" ("11 Corroborate
  /// — 300 m"): Yes goes through the SOS photo step as a real report (v10
  /// §2.2); No stops further alerts for this area.
  void _handleNeighborhood(RemoteMessage message) {
    final areaId = message.data['area_id'] as String?;
    if (areaId == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NeighbourAlertScreen(areaId: areaId)),
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
