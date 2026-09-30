import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/staff_shell.dart';

/// One console for responders and coordinators: the same top bar and the same
/// menu on every staff screen, with a tag saying which of the two it is.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const responder = {
    'id': 'u1',
    'full_name': 'M. Bautista',
    'role': 'response_team',
    'agency_type': 'fire_volunteer',
  };
  const coordinator = {
    'id': 'u2',
    'full_name': 'Ramon Dizon',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Hercules Fire Brigade',
  };
  const bfp = {
    'id': 'u3',
    'full_name': 'Ana Cruz',
    'role': 'sub_admin',
    'agency_type': 'bfp',
  };

  /// A dashboard with a button that opens a screen under it, as an incident
  /// opens from the dashboard.
  Future<void> pump(WidgetTester tester, Map<String, dynamic> me) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => StaffScaffold(
            me: me,
            page: StaffPage.dashboard,
            home: true,
            title: 'Dashboard',
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StaffScaffold(
                      me: me,
                      page: StaffPage.incidents,
                      title: 'Area 3',
                      body: const Text('the incident'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menu').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a responder: the RESPONDER tag and the responder menu', (
    tester,
  ) async {
    await pump(tester, responder);
    expect(tester.takeException(), isNull);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('RESPONDER'), findsOneWidget);
    expect(find.text('COORDINATOR'), findsNothing);

    await openMenu(tester);
    expect(find.text('M. Bautista'), findsOneWidget);
    for (final item in ['Dashboard', 'Incidents', 'My duty', 'Log out']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('Pending reports'), findsNothing);
    expect(find.text('Alarm requests'), findsNothing);
  });

  testWidgets('a coordinator: the COORDINATOR tag and the coordinator menu', (
    tester,
  ) async {
    await pump(tester, coordinator);
    expect(find.text('COORDINATOR'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Hercules Fire Brigade · Fire Volunteer'), findsOneWidget);
    expect(find.text('Pending reports'), findsOneWidget);
    expect(find.text('My duty'), findsNothing);
    expect(find.text('Alarm requests'), findsNothing, reason: 'BFP only');
  });

  testWidgets('BFP also has the alarm queue', (tester) async {
    await pump(tester, bfp);
    await openMenu(tester);
    expect(find.text('Alarm requests'), findsOneWidget);
    expect(find.text('Pending reports'), findsOneWidget);
  });

  testWidgets('inside an incident: Back, the same tag, and the same menu', (
    tester,
  ) async {
    await pump(tester, coordinator);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('AREA 3'), findsOneWidget);
    expect(find.text('COORDINATOR'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);

    // The menu is there too, and Dashboard goes home from it.
    await openMenu(tester);
    expect(find.text('Pending reports'), findsOneWidget);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('the incident'), findsNothing);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('Back leaves the incident for the dashboard', (tester) async {
    await pump(tester, responder);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
