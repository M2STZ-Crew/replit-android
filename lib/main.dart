import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api/push_service.dart';
import 'app_version.dart';
import 'api/report_queue.dart';
import 'screens/splash_screen.dart';
import 'widgets/responsive_frame.dart';
import 'theme.dart';
import 'theme_choice.dart';
import 'api/session.dart';
import 'models/active_report.dart';
import 'screens/report_status_screen.dart';

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
  // "1.11.0 (57)", as App Distribution lists this build.
  await AppVersion.load();
  // A report in progress survives the app being closed: read it now so the
  // first screen after sign-in can go straight back to it.
  await ActiveReportStore.load();
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the background with a report still out: go to it. Not while
  /// they are part-way through writing a new one, and never twice.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!Session.instance.isAuthenticated || ReportComposer.active) return;
    final report = ActiveReportStore.mine;
    final nav = PushService.navigatorKey.currentState;
    if (report == null || nav == null || ReportStatusScreen.isShowing) return;
    nav.push(ReportStatusScreen.route(report));
  }

  @override
  Widget build(BuildContext context) {
    // Both grounds from the hand-off. Which one shows is the switch in
    // Profile, not the phone's setting: rebuilt here so one tap repaints
    // every screen at once.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeChoice.light,
      builder: (context, light, _) => MaterialApp(
        title: 'RepLiT',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppPalette.light),
        darkTheme: buildAppTheme(AppPalette.dark),
        themeMode: light ? ThemeMode.light : ThemeMode.dark,
        scaffoldMessengerKey: PushService.messengerKey,
        navigatorKey: PushService.navigatorKey,
        // On a tablet the app keeps the column the design was drawn in
        // rather than stretching it across the room.
        builder: (context, child) =>
            ResponsiveFrame(child: child ?? const SizedBox.shrink()),
        home: const SplashScreen(),
      ),
    );
  }
}
