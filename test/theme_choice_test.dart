import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/theme.dart';
import 'package:replit/theme_choice.dart';

/// The ground is chosen in the app, not inherited from the phone: dark until
/// someone says otherwise, remembered after they do.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeChoice.reset();
  });

  test('dark is the default, and the phone does not get a vote', () async {
    await ThemeChoice.load();
    expect(ThemeChoice.light.value, isFalse);
    expect(ThemeChoice.palette, AppPalette.dark);
  });

  test('the choice survives a restart', () async {
    await ThemeChoice.set(true);
    expect(ThemeChoice.palette, AppPalette.light);

    // A fresh launch reads it back.
    ThemeChoice.reset();
    await ThemeChoice.load();
    expect(ThemeChoice.light.value, isTrue);
  });

  test('turning it off is remembered too', () async {
    await ThemeChoice.set(true);
    await ThemeChoice.set(false);
    ThemeChoice.reset();
    await ThemeChoice.load();
    expect(ThemeChoice.light.value, isFalse);
  });

  testWidgets('one tap repaints every screen', (tester) async {
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: ThemeChoice.light,
        builder: (context, light, _) => MaterialApp(
          theme: buildAppTheme(AppPalette.light),
          darkTheme: buildAppTheme(AppPalette.dark),
          themeMode: light ? ThemeMode.light : ThemeMode.dark,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.pal.background,
              body: Text('ground', style: context.type.cardTitle),
            ),
          ),
        ),
      ),
    );

    Color ground() =>
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
    expect(ground(), AppPalette.dark.background);

    // Flutter cross-fades between themes, so let the 200 ms land.
    await ThemeChoice.set(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ground(), AppPalette.light.background);

    await ThemeChoice.set(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ground(), AppPalette.dark.background);
  });
}
