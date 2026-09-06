import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api/push_service.dart';
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
  runApp(const RepLitApp());
}

class RepLitApp extends StatelessWidget {
  const RepLitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepLiT',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: PushService.messengerKey,
      navigatorKey: PushService.navigatorKey,
      home: const SplashScreen(),
    );
  }
}
