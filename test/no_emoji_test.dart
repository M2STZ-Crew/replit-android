import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/screens/login_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/no_emoji.dart';

/// v1.12.50 (18 Nov 2026): "make in any characters typing in every typebox in
/// the app and web cannot be typed by any emoji".
void main() {
  TextEditingValue typed(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );

  TextEditingValue format(String text, [int? cursor]) =>
      const NoEmojiFormatter().formatEditUpdate(
        TextEditingValue.empty,
        typed(text, cursor),
      );

  test('every text box in the app drops emoji', () {
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final call in RegExp(
        r'\b(TextField|TextFormField)\(',
      ).allMatches(source)) {
        // The call's arguments, to the matching parenthesis.
        var depth = 1;
        var i = call.end;
        while (i < source.length && depth > 0) {
          final ch = source[i];
          if (ch == '(') depth++;
          if (ch == ')') depth--;
          i++;
        }
        if (!source.substring(call.start, i).contains('NoEmojiFormatter')) {
          final line = '\n'.allMatches(source.substring(0, call.start)).length;
          missing.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(missing, isEmpty, reason: 'text boxes that still take emoji');
  });

  test('emoji, and everything that builds them, are dropped', () {
    for (final emoji in [
      '😀', // a face
      '👍🏽', // with a skin tone
      '👨‍👩‍👧', // a family, joined
      '🇵🇭', // a flag
      '❤️', // a heart, as emoji
      '✨', '⭐', '☀', '✅', '🔥', '🚒', // dingbats and pictographs
      '🏴󠁧󠁢󠁳󠁣󠁴󠁿', // a subdivision flag (tag letters)
    ]) {
      expect(format('Fire $emoji here').text, 'Fire  here', reason: emoji);
      expect(containsEmoji(emoji), isTrue, reason: emoji);
    }
  });

  test('a keycap leaves its plain digit', () {
    expect(format('Floor 1️⃣').text, 'Floor 1');
  });

  test('everything else goes in as typed', () {
    for (final text in [
      'Juan dela Cruz',
      'Niño Santo, Pasay — Bldg. #3 (2/F)',
      'maria+test@example.com',
      '0917 123 4567',
      'P@ssw0rd!_#*~',
      'Café © ® ™ ½ ° • …',
      '12:30 – 13:45',
    ]) {
      final out = format(text);
      expect(out.text, text);
      expect(containsEmoji(text), isFalse, reason: text);
    }
  });

  test('the cursor stays where it was among what is left', () {
    // "Fire 🔥| here": the cursor after the emoji lands after "Fire ".
    final out = format('Fire 🔥 here', 7);
    expect(out.text, 'Fire  here');
    expect(out.selection.baseOffset, 5);
    // A selection across emoji keeps its ends.
    final sel = const NoEmojiFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'a😀b😀c',
        selection: TextSelection(baseOffset: 1, extentOffset: 5),
      ),
    );
    expect(sel.text, 'abc');
    expect(sel.selection.baseOffset, 1);
    expect(sel.selection.extentOffset, 2);
    expect(withoutEmoji('a😀b'), 'ab');
  });

  testWidgets('typing emoji into the sign-in form leaves them out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const LoginScreen()),
    );
    await tester.pump();
    final email = find.widgetWithText(TextField, 'you@email.com');
    await tester.enterText(email, 'juan😀@example.com🔥');
    await tester.pump();
    final field = tester.widget<TextField>(email);
    expect(field.controller!.text, 'juan@example.com');
  });
}
