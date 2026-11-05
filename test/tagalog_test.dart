import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/i18n/i18n.dart';
import 'package:replit/i18n/tagalog.dart';
import 'package:replit/models/guide_article.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/models/responder_unit.dart';
import 'package:replit/models/verification_state.dart';
import 'package:replit/screens/id_camera_screen.dart';
import 'package:replit/widgets/app_nav_bar.dart';
import 'package:replit/widgets/map_marker.dart';

/// Tagalog mode (the 5 November issue list, 1.5): every line a resident can
/// read has its B1 Tagalog, with the same blanks to fill, and switching
/// language repaints what is on screen.
void main() {
  group('the dictionary is complete', () {
    test('every t() line in lib has a Tagalog entry', () {
      final missing = <String>[];
      for (final (key, where) in _literalKeys()) {
        if (!kTagalog.containsKey(key)) missing.add('$where: "$key"');
      }
      expect(missing, isEmpty, reason: 'add these to lib/i18n/tagalog.dart');
    });

    test('every line shown through t(value) has one too', () {
      final shown = <String>{
        kCatFire,
        kCatHealth,
        for (final a in kGuideArticles) ...[
          a.title,
          a.summary,
          a.intro,
          for (final s in a.sections) ...[s.heading, ...s.points],
        ],
        for (final h in kHotlines) ...[h.name, h.summary, h.description],
        for (final c in HotlineCategory.values) c.label,
        for (final u in kResponderUnits) ...[u.title, u.subtitle],
        for (final tab in AppTab.values) tab.label,
        for (final c in VerifyChannel.values) c.label,
        for (final k in MapMarkerKind.values) k.noun,
        for (final s in IdShot.values) ...[s.title, s.step, s.hint],
        // Private lists, read from their source.
        ..._literalsIn('lib/screens/help_center_screen.dart', '_faqs = ['),
        ..._literalsIn('lib/screens/onboarding_screen.dart', '_recap = ['),
        ..._literalsIn('lib/screens/sos_report_screen.dart', '_agencies = ['),
        ..._literalsIn('lib/screens/my_reports_screen.dart', '_months = ['),
        ..._literalsIn(
          'lib/screens/map_screen.dart',
          'const _incidents = _Layer(',
          'List<_Layer> _layers',
        ),
      };
      final missing = shown
          .where((s) => RegExp('[A-Za-z]').hasMatch(s))
          .where((s) => !RegExp(r'^[a-z0-9_]+$').hasMatch(s))
          .where((s) => !kTagalog.containsKey(s))
          .toList();
      expect(missing, isEmpty, reason: 'add these to lib/i18n/tagalog.dart');
    });

    test('each Tagalog line keeps the English blanks, and only those', () {
      Set<String> blanks(String s) => {
        for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!,
      };
      final wrong = [
        for (final MapEntry(:key, :value) in kTagalog.entries)
          if (!_sameSet(blanks(key), blanks(value))) key,
      ];
      expect(wrong, isEmpty);
    });

    test('no entry is left empty', () {
      expect(kTagalog.values.where((v) => v.trim().isEmpty), isEmpty);
    });
  });

  group('t()', () {
    tearDown(LanguageChoice.reset);

    test('English unless Tagalog is chosen', () {
      expect(t('Send report'), 'Send report');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(t('Send report'), 'Ipadala ang report');
    });

    test('a line with no entry stays English rather than going blank', () {
      LanguageChoice.current.value = AppLanguage.tl;
      expect(t('A line nobody has translated'), 'A line nobody has translated');
    });

    test('the blanks are filled in either language', () {
      expect(t('Step {n} of 6', {'n': 3}), 'Step 3 of 6');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(t('Step {n} of 6', {'n': 3}), 'Hakbang 3 sa 6');
    });

    test('how long ago, in Tagalog', () {
      LanguageChoice.current.value = AppLanguage.tl;
      final now = DateTime(2026, 11, 5, 12);
      expect(
        tAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5 minuto na ang nakalipas',
      );
      expect(
        tAgo(now.subtract(const Duration(days: 1)), now: now),
        '1 araw na ang nakalipas',
      );
    });
  });

  group('choosing a language', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(LanguageChoice.reset);

    test('is kept on the phone', () async {
      await LanguageChoice.set(AppLanguage.tl);
      LanguageChoice.reset();
      await LanguageChoice.load();
      expect(LanguageChoice.current.value, AppLanguage.tl);
    });

    testWidgets('repaints the screen in place, const widgets too', (
      tester,
    ) async {
      var typed = '';
      await tester.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const _Label('Send report'),
                  // State that must survive the switch.
                  TextField(onChanged: (v) => typed = v),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'kept');
      expect(find.text('Send report'), findsOneWidget);

      LanguageChoice.current.value = AppLanguage.tl;
      await tester.pump();
      expect(find.text('Ipadala ang report'), findsOneWidget);
      expect(find.text('kept'), findsOneWidget, reason: 'nothing was rebuilt');
      expect(typed, 'kept');
    });
  });
}

/// A const widget whose text comes from t(): the case a plain rebuild of the
/// app root would miss.
class _Label extends StatelessWidget {
  const _Label(this.en);

  final String en;

  @override
  Widget build(BuildContext context) => Text(t(en));
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Every literal passed straight to t() in lib, with where it is.
Iterable<(String, String)> _literalKeys() sync* {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !f.path.replaceAll(r'\', '/').endsWith('i18n/tagalog.dart'),
      );
  for (final file in files) {
    final src = _withoutComments(file.readAsStringSync());
    for (final m in RegExp(r'(?<![A-Za-z0-9_])t\(').allMatches(src)) {
      final key = _readSequence(src, m.end);
      if (key != null) {
        final line = src.substring(0, m.start).split('\n').length;
        yield (key, '${file.path}:$line');
      }
    }
  }
}

/// The string literals between [marker] and the next [end] in [path].
List<String> _literalsIn(String path, String marker, [String end = '];']) {
  final src = _withoutComments(File(path).readAsStringSync());
  final start = src.indexOf(marker);
  if (start < 0) throw StateError('$marker not found in $path');
  final stop = src.indexOf(end, start);
  final part = src.substring(start, stop);
  final found = <String>[];
  var i = 0;
  while (i < part.length) {
    if (part[i] == "'" || part[i] == '"') {
      // Adjacent literals are one string to Dart, so one entry here.
      final lit = _readLiteral(part, i);
      if (lit != null) {
        var end = lit.$2;
        final value = _readSequence(part, i) ?? lit.$1;
        // Skip past every literal the sequence took in.
        while (true) {
          var k = end;
          while (k < part.length && part[k].trim().isEmpty) {
            k++;
          }
          final next = _readLiteral(part, k);
          if (next == null) break;
          end = next.$2;
        }
        found.add(value);
        i = end;
        continue;
      }
    }
    i++;
  }
  return found;
}

/// Comment lines out, so examples in doc comments are not taken for keys.
String _withoutComments(String src) => src
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((l) => l.trimLeft().startsWith('//') ? '' : l)
    .join('\n');

/// Adjacent literals from [i] on, concatenated; null for none, or for one
/// that interpolates.
String? _readSequence(String src, int i) {
  final out = StringBuffer();
  var k = i;
  var any = false;
  while (true) {
    while (k < src.length && src[k].trim().isEmpty) {
      k++;
    }
    final lit = _readLiteral(src, k);
    if (lit == null) break;
    out.write(lit.$1);
    k = lit.$2;
    any = true;
  }
  return any ? out.toString() : null;
}

/// One literal at [i]: its value and the index after it.
(String, int)? _readLiteral(String src, int i) {
  if (i >= src.length) return null;
  final q = src[i];
  if (q != "'" && q != '"') return null;
  final out = StringBuffer();
  var k = i + 1;
  while (k < src.length) {
    final c = src[k];
    if (c == '\n') return null;
    if (c == r'\') {
      final n = src[k + 1];
      out.write(n == 'n' ? '\n' : n);
      k += 2;
      continue;
    }
    if (c == r'$') return null;
    if (c == q) return (out.toString(), k + 1);
    out.write(c);
    k++;
  }
  return null;
}
