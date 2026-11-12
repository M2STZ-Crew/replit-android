// Brings the supplied LIT tutorial assets into the app (assets/tutorial).
//
//     dart run tool/tutorial/import_lit.dart "<TUTORIAL ASSETS folder>"
//
// The supplied folder stays as it is. Its files are named for people, with
// spaces and a middle dot ("ENGLISH_01 · Welcome .mp3", a space before the
// extension); the app's copies are named for the lesson they belong to, and
// lib/tutorial/lit_lessons.dart refers to them by those names, never by a
// display title.
//
// - The six poses and the five talking frames are drawn at 512 × 512 (the
//   talking loop's own size, timing.json "animation_width"), from 1254 ×
//   1254: four times the 128 px Lit is drawn at, on a 3x phone, at a tenth
//   of the weight. Scaled, never redrawn or cropped, so every pose keeps the
//   same canvas, size and foot line.
// - timing.json comes along with its frame names changed to the copies'.
// - face.png: Lit's head, cut from the resting frame, for small round places.
// - The voice clips are copied as they are, except the two whose words do not
//   match the app (02 "Tap Report Incident" where the app's SOS is held; 03
//   "may be different from where you are" where a report carries the phone's
//   own location): those lessons show their captions without a clip until
//   new recordings are made (lit_lessons.dart). Those came on 13 November
//   2026 ("NEW UPDATE"), with the report's receipt, and were copied in as
//   02_tap_sos, 02_hold_sos, 02_photo, 03_check_location and
//   06_report_received.
// - The animated WebP, the previews and the generation notes stay out.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _poses = {
  '01_lit_wave.png': 'pose_wave.png',
  '02_lit_point_upper_left.png': 'pose_point_upper_left.png',
  '03_lit_point_upper_right.png': 'pose_point_upper_right.png',
  '04_lit_present.png': 'pose_present.png',
  '05_lit_review.png': 'pose_review.png',
  '06_lit_approve.png': 'pose_approve.png',
};

const _frames = {
  'lit_idle_closed.png': 'talk_idle_closed.png',
  'lit_talk_mid.png': 'talk_mid.png',
  'lit_talk_wide.png': 'talk_wide.png',
  'lit_talk_o.png': 'talk_o.png',
  'lit_blink.png': 'talk_blink.png',
};

/// Lesson → its clip's name in each supplied folder. 02 and 03 are left out
/// (see above).
const _voice = {
  '01_welcome': ('ENGLISH_01 · Welcome .mp3', 'TAGALOG_01 · Welcome.mp3'),
  '04_select_organization': (
    'ENGLISH_04 · Select organization.mp3',
    'TAGALOG_04 · Select organization.mp3',
  ),
  '05_review_details': (
    'ENGLISH_05 · Review details.mp3',
    'TAGALOG_05 · Review details.mp3',
  ),
  '06_practice_submit': (
    'ENGLISH_06 · Practice submit.mp3',
    'TAGALOG_06 · Practice submit.mp3',
  ),
  '07_follow_updates': (
    'ENGLISH_07 · Follow updates.mp3',
    'TAGALOG_07 · Follow updates.mp3',
  ),
  '08_finish': ('ENGLISH_08 · Finish.mp3', 'TAGALOG_08 · Finish.mp3'),
};

const _size = 512;

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/tutorial/import_lit.dart <folder>');
    exit(64);
  }
  final source = Directory(args.single);
  final out = Directory('assets/tutorial');
  final lit = Directory('${out.path}/lit')..createSync(recursive: true);

  void scale(String from, String to) {
    final picture = img.decodePng(File(from).readAsBytesSync());
    if (picture == null) throw StateError('not a PNG: $from');
    final small = img.copyResize(
      picture,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
    File('${lit.path}/$to').writeAsBytesSync(img.encodePng(small, level: 9));
    stdout.writeln('lit/$to');
  }

  final poses = '${source.path}/POSES/LIT-Tutorial-Poses';
  _poses.forEach((from, to) => scale('$poses/$from', to));
  final talking = '${source.path}/POSES/LIT-Talking-Animation';
  _frames.forEach((from, to) => scale('$talking/frames/$from', to));

  // Lit's face, for a small round place (the coordinator's "Writing the
  // CIAR"): his head and helmet from the resting frame, cut square and drawn
  // at 192 px, three times the 64 px circle.
  final resting = img.decodePng(
    File('$talking/frames/lit_idle_closed.png').readAsBytesSync(),
  )!;
  final face = img.copyResize(
    img.copyCrop(resting, x: 340, y: 90, width: 600, height: 600),
    width: 192,
    height: 192,
    interpolation: img.Interpolation.average,
  );
  File('${lit.path}/face.png').writeAsBytesSync(img.encodePng(face, level: 9));
  stdout.writeln('lit/face.png');

  final timing =
      jsonDecode(File('$talking/timing.json').readAsStringSync())
          as Map<String, dynamic>;
  String renamed(String file) => _frames[file.split('/').last]!;
  timing['idle_frame'] = renamed(timing['idle_frame'] as String);
  for (final step in timing['sequence'] as List) {
    (step as Map<String, dynamic>)['file'] = renamed(step['file'] as String);
  }
  File(
    '${lit.path}/timing.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(timing));
  stdout.writeln('lit/timing.json');

  _voice.forEach((lesson, files) {
    final (english, tagalog) = files;
    for (final (language, folder, name) in [
      ('en', 'ENGLISH', english),
      ('tl', 'TAGALOG', tagalog),
    ]) {
      final dir = Directory('${out.path}/voice/$language')
        ..createSync(recursive: true);
      File(
        '${source.path}/VOICE/$folder/$name',
      ).copySync('${dir.path}/$lesson.mp3');
      stdout.writeln('voice/$language/$lesson.mp3');
    }
  });
}
