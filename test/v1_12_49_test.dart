import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/email_gate.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/screens/email_gate_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/alarm_ask_sheet.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/fire_type_row.dart';

/// v1.12.49 (18 Nov 2026: "an illegitimate email can still sign up (the
/// account was created because of the Later button)"): a resident's RepLiT
/// stays locked until the emailed link is opened.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  http.Response json(int status, Object body) =>
      http.Response(jsonEncode(body), status);

  Map<String, dynamic> standing({required bool email}) => {
    'verified_percent': email ? 10 : 0,
    'badge': 'yellow',
    'channels': [
      if (email) {'type': 'email', 'status': 'verified'},
    ],
  };

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('a refusal for an unconfirmed email opens Confirm your email', () async {
    var tripped = 0;
    EmailGate.onTrip = () => tripped++;
    addTearDown(() => EmailGate.onTrip = null);
    final api = ApiClient(
      client: MockClient(
        (_) async => json(403, {
          'error': 'email_not_verified',
          'message': 'Confirm your email before using your RepLiT account.',
        }),
      ),
    );
    await expectLater(api.getMe(), throwsA(isA<ApiException>()));
    expect(tripped, 1);
  });

  testWidgets('RoleGate shows Confirm your email, with no Later', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path == '/verification/status') {
          return json(200, standing(email: false));
        }
        return json(200, {'status': 'ok'});
      }),
    );
    await show(tester, EmailGateScreen(email: 'juan@example.com', api: api));
    expect(EmailGate.isShowing, isTrue);
    expect(find.text('CONFIRM YOUR EMAIL'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Emergency now? Call 911'), findsOneWidget);
    expect(find.byKey(const ValueKey('email-start-over')), findsOneWidget);
    expect(find.byKey(const ValueKey('email-gate-log-out')), findsOneWidget);
    // Nothing is sent by opening it.
    expect(find.text('SEND THE LINK'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(EmailGate.isShowing, isFalse);
  });

  testWidgets('a link opened elsewhere is seen, and Continue goes on in', (
    tester,
  ) async {
    var confirmed = false;
    var verified = false;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path == '/verification/status') {
          return json(200, standing(email: verified));
        }
        return json(200, {'status': 'ok'});
      }),
    );
    await show(
      tester,
      EmailGateScreen(
        email: 'juan@example.com',
        api: api,
        onConfirmed: () => confirmed = true,
      ),
    );
    expect(find.text('CONFIRM YOUR EMAIL'), findsOneWidget);
    // Opened on a computer: the next look sees it.
    verified = true;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EMAIL CONFIRMED'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(confirmed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('RoleGate puts the gate before anything else', (tester) async {
    // The gate's own client: a test's HTTP is refused, which it takes as
    // not confirmed yet.
    await show(
      tester,
      const RoleGate(
        initialMe: {
          'id': 'u1',
          'role': 'general_user',
          'email': 'juan@example.com',
          'email_verification_required': true,
          'phone_verification_required': true,
        },
      ),
    );
    expect(find.byType(EmailGateScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // "even outside of 100m everyone get notified": a verified fire, told to
  // every resident, opens its details; staff go to the incident.
  test('a verified fire opens its details for a resident', () {
    expect(fireAlertTypes, contains('fire_verified'));
    expect(
      targetFor('fire_verified', const {'role': 'general_user'}),
      NotificationTarget.verifiedFire,
    );
    expect(
      targetFor('fire_verified', const {'role': 'sub_admin'}),
      NotificationTarget.staffIncident,
    );
  });

  // "bfp coordinator can raise an alarm without the request of fv".
  testWidgets('BFP raises the alarm itself, with the requests a tap away', (
    tester,
  ) async {
    AlarmAsk? got;
    final area = AreaView(const {
      'id': 'a1',
      'designation': '1.2',
      'status': 'arrived',
      'alarm_level': 'first_alarm',
    });
    await show(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => got = await showModalBottomSheet<AlarmAsk>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                AlarmAskSheet(area: area, bfp: true, requestsWaiting: 2),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Raise the alarm?'), findsOneWidget);
    expect(find.text('2 escalations waiting'), findsOneWidget);
    await tester.tap(find.text('2nd alarm'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Raise to 2nd alarm',
      ),
    );
    await tester.pumpAndSettle();
    expect(got?.level, 'second_alarm');
    expect(got?.openRequests, isFalse);
  });

  // "make all of the user aware in the details of the incident".
  testWidgets('a resident reads the fire type and the team that said it', (
    tester,
  ) async {
    await show(
      tester,
      const Scaffold(
        body: Column(
          children: [
            ResidentFireTypeRow(
              area: {
                'fire_type': 'structural',
                'fire_subtype': 'residential',
                'fire_type_org_name': 'BFP Pasay City Fire Station',
              },
            ),
            ResidentFireTypeRow(area: {'fire_type': null}),
          ],
        ),
      ),
    );
    expect(find.text('Fire type'), findsOneWidget);
    expect(
      find.text('Structural — Residential · BFP Pasay City Fire Station'),
      findsOneWidget,
    );
  });
}
