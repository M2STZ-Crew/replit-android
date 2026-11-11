import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/theme.dart';
import 'package:replit/theme_choice.dart';

/// System, Light or Dark (12 November 2026: "add 'System' to dark/light mode,
/// detecting the phone's mode"). System is the default and follows the
/// phone; a choice made before stays; Light and Dark ignore the phone.
void main() {
  var phone = Brightness.dark;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeChoice.reset();
    phone = Brightness.dark;
    ThemeChoice.phoneBrightness = () => phone;
  });

  test('System is the default, and it follows the phone', () async {
    phone = Brightness.light;
    await ThemeChoice.load();
    expect(ThemeChoice.pick.value, ThemePick.system);
    expect(ThemeChoice.light.value, isTrue);
    expect(ThemeChoice.palette, AppPalette.light);

    phone = Brightness.dark;
    ThemeChoice.phoneChanged();
    expect(ThemeChoice.light.value, isFalse);
    expect(ThemeChoice.palette, AppPalette.dark);
  });

  test('a choice made before System existed is kept', () async {
    SharedPreferences.setMockInitialValues({'theme_light_v1': true});
    phone = Brightness.dark;
    await ThemeChoice.load();
    expect(ThemeChoice.pick.value, ThemePick.light);
    expect(ThemeChoice.light.value, isTrue);

    SharedPreferences.setMockInitialValues({'theme_light_v1': false});
    phone = Brightness.light;
    await ThemeChoice.load();
    expect(ThemeChoice.pick.value, ThemePick.dark);
    expect(ThemeChoice.light.value, isFalse);
  });

  test('Light and Dark hold whatever the phone does', () async {
    await ThemeChoice.choose(ThemePick.dark);
    phone = Brightness.light;
    ThemeChoice.phoneChanged();
    expect(ThemeChoice.light.value, isFalse);

    await ThemeChoice.choose(ThemePick.light);
    phone = Brightness.dark;
    ThemeChoice.phoneChanged();
    expect(ThemeChoice.light.value, isTrue);
  });

  test('the choice survives a restart', () async {
    await ThemeChoice.choose(ThemePick.light);
    expect(ThemeChoice.palette, AppPalette.light);

    // A fresh launch reads it back.
    ThemeChoice.reset();
    ThemeChoice.phoneBrightness = () => Brightness.dark;
    await ThemeChoice.load();
    expect(ThemeChoice.pick.value, ThemePick.light);
    expect(ThemeChoice.light.value, isTrue);

    await ThemeChoice.choose(ThemePick.system);
    ThemeChoice.reset();
    ThemeChoice.phoneBrightness = () => Brightness.dark;
    await ThemeChoice.load();
    expect(ThemeChoice.pick.value, ThemePick.system);
    expect(ThemeChoice.light.value, isFalse);
  });

  testWidgets('one tap repaints every screen', (tester) async {
    await ThemeChoice.choose(ThemePick.dark);
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
    await ThemeChoice.choose(ThemePick.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ground(), AppPalette.light.background);

    await ThemeChoice.choose(ThemePick.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ground(), AppPalette.dark.background);
  });
}
