import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/phone_gate.dart';
import 'api/push_service.dart';
import 'app_version.dart';
import 'api/report_queue.dart';
import 'screens/splash_screen.dart';
import 'widgets/launch_mark.dart';
import 'updates/update_nudge.dart';
import 'theme.dart';
import 'theme_choice.dart';
import 'i18n/i18n.dart';
import 'location/location_beacon.dart';
import 'privacy/contact_mask.dart';
import 'security/developer_mode.dart';
import 'api/session.dart';
import 'models/active_report.dart';
import 'screens/phone_verify_screen.dart';
import 'screens/report_status_screen.dart';
import 'screens/role_gate.dart';
import 'alerts/inbox_watcher.dart';
import 'location/last_place.dart';
import 'screens/signed_in_elsewhere_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    PushService.instance.initListeners();
  } catch (_) {
    // Firebase not configured yet (no google-services.json) — the app still
    // runs; push notifications are simply inactive until it's set up.
  }
  // The ground the app draws on is a choice made inside it, so it has to be
  // read before the first frame or the app flashes the wrong one.
  await ThemeChoice.load();
  // The splash's mark is decoded before its first frame, so the phone's
  // launch screen hands over to it without the mark blinking.
  await LaunchMark.precache();
  await ContactMask.load();
  await LanguageChoice.load();
  await LocationBeacon.init();
  // An iPhone has no push: the open app reads the inbox for news, and rings
  // and vibrates as a push would (lib/alerts/inbox_watcher.dart).
  InboxWatcher.instance.start();
  // One phone per account: a newer sign-in elsewhere puts up the warning
  // and Exit over every screen (lib/screens/signed_in_elsewhere_screen.dart).
  ApiClient.onSignedInElsewhere = () =>
      PushService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const SignedInElsewhereScreen(),
        ),
        (_) => false,
      );
  // "1.11.0 (57)", as App Distribution lists this build.
  await AppVersion.load();
  // A report in progress survives the app being closed: read it now so the
  // first screen after sign-in can go straight back to it.
  await ActiveReportStore.load();
  // Where the map opens: the last spot this phone knew (v1.12.43).
  await LastPlace.load();
  // A report saved with no signal in an earlier session starts retrying now,
  // and says so wherever the person is in the app when it finally goes.
  unawaited(ReportQueue.instance.load());
  ReportQueue.instance.delivered.listen((report) {
    PushService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Your saved report was sent.')),
    );
    // Now it is a real report, follow it like any other.
    unawaited(
      ActiveReportStore.adoptDelivered(
        lat: report.lat,
        lng: report.lng,
        agencies: report.agencies,
      ),
    );
  });
  // A request refused mid-session because the account's phone is not
  // verified: show the gate over whatever was open. Verified, the app starts
  // again from RoleGate, which now lets the resident through.
  PhoneGate.onTrip = () {
    final nav = PushService.navigatorKey.currentState;
    if (nav == null || !Session.instance.isAuthenticated) return;
    PhoneGate.opened();
    nav.push(
      MaterialPageRoute(
        builder: (_) => PhoneVerifyScreen(
          gate: true,
          onVerified: () => nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const RoleGate()),
            (route) => false,
          ),
        ),
      ),
    );
  };
  runApp(const RepLitApp());
}

class RepLitApp extends StatefulWidget {
  const RepLitApp({super.key});

  @override
  State<RepLitApp> createState() => _RepLitAppState();
}

class _RepLitAppState extends State<RepLitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepLocationFresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationBeacon.stopOpen();
    super.dispose();
  }

  /// The phone went light or dark: with Theme on System, so does the app.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    ThemeChoice.phoneChanged();
  }

  /// While the app is open its location reaches the server every few minutes,
  /// so the 100 m alert finds the resident where they are now. Closed, that is
  /// WorkManager's job, where the resident allows it (LocationBeacon).
  void _keepLocationFresh() {
    LocationBeacon.startOpen(
      () => PushService.instance.refreshLocation(ask: false),
    );
  }

  /// Back from the background with a report still out: go to it. Not while
  /// they are part-way through writing a new one, and never twice.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) LocationBeacon.stopOpen();
    if (state != AppLifecycleState.resumed) return;
    _keepLocationFresh();
    unawaited(_syncClosedReports());
    // Back to the front: a newer release? (At most every 15 minutes.)
    unawaited(UpdateNudge.maybeCheck());
    if (!Session.instance.isAuthenticated || ReportComposer.active) return;
    final report = ActiveReportStore.mine;
    final nav = PushService.navigatorKey.currentState;
    if (report == null || nav == null || ReportStatusScreen.isShowing) return;
    nav.push(ReportStatusScreen.route(report));
  }

  /// Back from Settings, location may now be allowed "All the time" (or no
  /// longer): schedule or cancel the closed-app reports to match.
  Future<void> _syncClosedReports() async {
    if (!Session.instance.isAuthenticated) return;
    await LocationBeacon.syncClosed(
      alertsOn: await PushService.instance.isEnabled(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Both grounds from the hand-off. Which one shows is Profile's Theme:
    // System (the phone's light or dark), Light or Dark, resolved by
    // ThemeChoice and rebuilt here so one tap repaints every screen at once.
    // Everything under LanguageScope repaints when the language changes.
    return LanguageScope(
      child: ValueListenableBuilder<bool>(
        valueListenable: ThemeChoice.light,
        builder: (context, light, _) => MaterialApp(
          title: 'RepLiT',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppPalette.light),
          darkTheme: buildAppTheme(AppPalette.dark),
          themeMode: light ? ThemeMode.light : ThemeMode.dark,
          scaffoldMessengerKey: PushService.messengerKey,
          navigatorKey: PushService.navigatorKey,
          // On a tablet each screen keeps the column the design was drawn
          // in, or fills the tablet when it is a map or a camera: each page
          // has its own frame (ResponsiveFrame, through the theme's page
          // transitions; v1.12.43), not the whole app one.
          //
          // Over all of it, a release build's block while Android's Developer
          // options are on (lib/security/developer_mode.dart).
          builder: (context, child) =>
              DeveloperModeGate(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
