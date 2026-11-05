import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/models/guide_article.dart';
import 'package:replit/screens/call_screen.dart';
import 'package:replit/screens/edit_profile_screen.dart';
import 'package:replit/screens/guide_detail_screen.dart';
import 'package:replit/screens/guide_screen.dart';
import 'package:replit/screens/help_center_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/my_reports_screen.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/screens/notifications_screen.dart';
import 'package:replit/screens/onboarding_screen.dart';
import 'package:replit/screens/phone_verify_screen.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/register_screen.dart';
import 'package:replit/screens/sos_report_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/theme.dart';

/// Tagalog runs longer than English. Every resident screen is drawn in
/// Tagalog on the smallest phone the app supports at the larger text sizes
/// people use, and fails on any overflow (the 5 November issue list, 1.5).
void main() {
  // A one-pixel PNG: enough for Image.memory to draw something.
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/verification/status')) {
        return http.Response(
          jsonEncode({
            'verified_percent': 50,
            'badge': 'yellow',
            'channels': [
              {'type': 'email', 'status': 'pending'},
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/reports/mine') || path.endsWith('/notifications')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        jsonEncode({
          'id': 'u1',
          'email': 'm.reyes@gmail.com',
          'full_name': 'Maria Antonette Reyes',
          'role': 'general_user',
          'mobile': '+639171234567',
        }),
        200,
      );
    }),
  );

  final screens = <String, Widget Function()>{
    'onboarding': () => const OnboardingScreen(),
    'login': () => LoginScreen(api: api()),
    'register': () => RegisterScreen(api: api()),
    'phone verification': () => PhoneVerifyScreen(api: api()),
    'report': () => SosReportScreen(photoBytes: pixel, api: api()),
    'national ID': () => NationalIdScreen(
      api: api(),
      camera: () async => Uint8List.fromList(pixel),
    ),
    'verification': () => VerificationScreen(api: api()),
    'profile': () => ProfileScreen(api: api()),
    'edit profile': () =>
        const EditProfileScreen(fullName: 'Maria Antonette Reyes'),
    'my reports': () => MyReportsScreen(api: api()),
    'notifications': () => NotificationsScreen(api: api()),
    'guides': () => const GuideScreen(),
    'a guide': () => GuideDetailScreen(article: kGuideArticles.first),
    'hotlines': () => const CallScreen(),
    'help center': () => const HelpCenterScreen(),
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageChoice.current.value = AppLanguage.tl;
  });
  tearDown(LanguageChoice.reset);

  for (final (size, scale) in const [
    (Size(320, 640), 1.3),
    (Size(402, 874), 1.5),
  ]) {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets(
        '$name fits in Tagalog at ${size.width.round()} px, ${scale}x text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            LanguageScope(
              child: MaterialApp(
                theme: buildAppTheme(),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: screen(),
                  ),
                ),
              ),
            ),
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(tester.takeException(), isNull);
          // Let screens with a timer (the tour's coach marks, say) finish.
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
