import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/guide_article.dart';
import 'package:replit/screens/call_screen.dart';
import 'package:replit/screens/change_password_screen.dart';
import 'package:replit/screens/delete_account_screen.dart';
import 'package:replit/screens/guide_detail_screen.dart';
import 'package:replit/screens/guide_screen.dart';
import 'package:replit/screens/help_center_screen.dart';
import 'package:replit/screens/home_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/my_reports_screen.dart';
import 'package:replit/screens/edit_profile_screen.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/screens/neighbour_alert_screen.dart';
import 'package:replit/screens/notification_settings_screen.dart';
import 'package:replit/screens/notifications_screen.dart';
import 'package:replit/screens/phone_verify_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/register_screen.dart';
import 'package:replit/screens/signed_in_elsewhere_screen.dart';
import 'package:replit/screens/bfp/bfp_alarm_requests_screen.dart';
import 'package:replit/screens/coordinator/area_decision_screen.dart';
import 'package:replit/screens/responder/responder_incident_screen.dart';
import 'package:replit/screens/subadmin/ai_summaries_screen.dart';
import 'package:replit/screens/subadmin/pending_reports_screen.dart';
import 'package:replit/screens/subadmin/post_incident_report_screen.dart';
import 'package:replit/screens/subadmin/report_filed_screen.dart';
import 'package:replit/screens/subadmin/subadmin_incident_command_screen.dart';
import 'package:replit/screens/subadmin/team_screen.dart';
import 'package:replit/theme.dart';

/// The smallest phones people still carry: a 320-wide iPhone SE and a
/// 375-wide one, at normal text and at Android's "Largest" font (1.3x).
///
/// The other fit tests start at 360 wide. Every screen here must build there
/// without an overflow, including when the server is down (the error state).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The server is down: every screen that asks shows its error state.
  ApiClient offline() =>
      ApiClient(client: MockClient((req) async => http.Response('{}', 503)));

  const police = {
    'id': 'pnp',
    'role': 'sub_admin',
    'agency_type': 'police',
    'organization_name': 'PNP Pasay',
    'full_name': 'P. Cruz',
  };
  const chief = {
    'id': 'bfp',
    'role': 'sub_admin',
    'agency_type': 'fire',
    'organization_name': 'BFP Pasay City Fire Station',
    'full_name': 'Fire Chief Maria Dela Cruz-Villanueva',
  };

  final longest = kGuideArticles.reduce(
    (a, b) => a.sections.length >= b.sections.length ? a : b,
  );

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'hotlines': () => const CallScreen(),
    'guides': () => const GuideScreen(),
    'a guide article': () => GuideDetailScreen(article: longest),
    'sign in': () => const LoginScreen(),
    'sign up': () => const RegisterScreen(),
    'national ID': () => const NationalIdScreen(),
    'help center': () => const HelpCenterScreen(),
    'signed in elsewhere': () => const SignedInElsewhereScreen(),
    'change password': () => ChangePasswordScreen(api: offline()),
    'delete account': () => DeleteAccountScreen(api: offline()),
    'profile, server down': () => ProfileScreen(api: offline()),
    'my reports, server down': () => MyReportsScreen(api: offline()),
    // Staff screens, server down.
    'coordinator: area decision': () =>
        AreaDecisionScreen(areaId: 'a1', me: police, api: offline()),
    'chief: incident command': () =>
        SubAdminIncidentCommandScreen(areaId: 'a1', me: chief, api: offline()),
    'responder: incident': () =>
        ResponderIncidentScreen(incidentId: 'a1', myId: 'u1', api: offline()),
    'chief: AI summaries': () => AiSummariesScreen(me: chief, api: offline()),
    'chief: pending reports': () => PendingReportsScreen(api: offline()),
    'chief: post-incident report': () =>
        PostIncidentReportScreen(areaId: 'a1', api: offline()),
    'chief: report filed': () =>
        ReportFiledScreen(areaId: 'a1', api: offline()),
    'chief: team': () => TeamScreen(me: chief, api: offline()),
    'BFP: alarm requests': () => BfpAlarmRequestsScreen(api: offline()),
    'notifications, server down': () => NotificationsScreen(api: offline()),
    'notification settings': () => const NotificationSettingsScreen(),
    'edit profile': () => const EditProfileScreen(
      fullName: 'Maria Concepcion Dela Cruz-Villanueva',
      mobile: '09171234567',
    ),
    'verify phone': () => PhoneVerifyScreen(
      gate: true,
      initialPhone: '09171234567',
      api: offline(),
    ),
    'verification, server down': () => VerificationScreen(api: offline()),
    'neighbour alert, server down': () =>
        NeighbourAlertScreen(areaId: 'a1', api: offline()),
  };

  for (final size in const [Size(320, 568), Size(375, 667)]) {
    for (final scale in const [1.0, 1.3]) {
      group('${size.width.round()}x${size.height.round()} at ${scale}x', () {
        for (final MapEntry(key: name, value: build) in screens.entries) {
          testWidgets(name, (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: buildAppTheme(),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: build(),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull);
            // Let any timers and requests wind down with the screen.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 6));
          });
        }
      });
    }
  }
}
