import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api/push_service.dart';
import 'api/report_queue.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

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
  // A report saved with no signal in an earlier session starts retrying now,
  // and says so wherever the person is in the app when it finally goes.
  unawaited(ReportQueue.instance.load());
  ReportQueue.instance.delivered.listen((_) {
    PushService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Your saved report was sent.')),
    );
  });
  runApp(const RepLitApp());
}

class RepLitApp extends StatelessWidget {
  const RepLitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepLiT',
      debugShowCheckedModeBanner: false,
      // Both grounds from the hand-off. Which one shows follows the phone:
      // a resident who has set their phone to light should not be handed a
      // black screen at noon, and one who has set it to dark should not be
      // flashbanged at 3am.
      theme: buildAppTheme(AppPalette.light),
      darkTheme: buildAppTheme(AppPalette.dark),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: PushService.messengerKey,
      navigatorKey: PushService.navigatorKey,
      home: const SplashScreen(),
    );
  }
}
