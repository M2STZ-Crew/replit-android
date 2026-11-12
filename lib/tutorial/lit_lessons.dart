/// The LIT tutorial's lessons: what each one teaches, the real control it
/// lights, the clip Lit says it with in each language, its caption, and the
/// pose Lit holds once the clip is over.
///
/// Lessons are named by a stable id ("01".."08"), never by their place on
/// screen or their title: a clip stays with its lesson whatever the order.
/// The files are the supplied recordings, copied into assets/tutorial by
/// tool/tutorial/import_lit.dart; 02's three parts, 03 and the report's
/// receipt ([kReceivedClip]) are the recordings of 13 November 2026, made
/// for the real screens' words ("NEW UPDATE").
library;

/// The tutorial's two languages, the app's own: chosen once, on the first
/// screen, for Lit's voice, his captions and the app together.
enum LitLanguage {
  en('English'),
  tl('Tagalog');

  const LitLanguage(this.label);

  /// The language's own name, the same in either language.
  final String label;
}

/// Lit's still poses (assets/tutorial/lit). The pointing ones name the
/// direction on screen: upper-left points up and to the left, from a Lit
/// standing to the right of what he points at. Never mirrored.
enum LitPose {
  wave('pose_wave'),
  pointUpperLeft('pose_point_upper_left'),
  pointUpperRight('pose_point_upper_right'),
  present('pose_present'),
  review('pose_review'),
  approve('pose_approve');

  const LitPose(this.file);

  final String file;

  String get asset => 'assets/tutorial/lit/$file.png';
}

/// What a lesson asks of the resident before it moves on.
enum LitAction {
  /// Start Tutorial (the welcome).
  start,

  /// Tap SOS in the bar at the bottom of the map.
  tapSos,

  /// Hold the SOS button for its two seconds.
  holdSos,

  /// Take the photo.
  shutter,

  /// Tap the highlighted agency.
  chooseAgency,

  /// Read, then Continue.
  read,

  /// Submit Practice Report.
  submit,

  /// Finish.
  finish,
}

/// The real controls a lesson lights, by the name their screens give them
/// ([PracticeTarget], lib/tutorial/practice.dart).
abstract final class LitTargets {
  static const String sosDisc = 'sos_disc';
  static const String sosDial = 'sos_dial';
  static const String shutter = 'shutter';
  static const String location = 'location_chip';
  static const String medical = 'agency_medical';
  static const String form = 'report_form';
  static const String send = 'send_button';
  static const String updates = 'status_steps';

  /// The agency [medical] lights: the one the practice chooses.
  static const String medicalAgency = 'medical';
}

/// One lesson (or a part of one: 02 is tapping SOS, holding it, and the
/// photo).
class LitLesson {
  const LitLesson({
    required this.id,
    required this.name,
    required this.action,
    required this.pose,
    required this.captionEn,
    required this.captionTl,
    this.target,
    this.clip,
    this.part = false,
  });

  /// "01".."08": the lesson's number, and its clips'.
  final String id;

  /// The clip's file name without the language ("04_select_organization").
  /// Every lesson has one; null would leave a lesson captioned only.
  final String? clip;

  /// A short name, for tests and logs.
  final String name;
  final LitAction action;

  /// The real control it lights ([LitTargets]), if it has one.
  final String? target;

  /// Lit's pose once the clip is over (or at once, without one). A pointing
  /// lesson turns this to the side its control is on.
  final LitPose pose;

  final String captionEn;
  final String captionTl;

  /// A later part of a lesson, sharing its number.
  final bool part;

  String caption(LitLanguage language) =>
      language == LitLanguage.tl ? captionTl : captionEn;

  /// The clip for [language], or null when this lesson has none.
  String? clipAsset(LitLanguage language) =>
      clip == null ? null : litClipAsset(clip!, language);

  /// Whether the lesson waits for a touch on its real control (the rest
  /// are read, then Continue).
  bool get touches => const {
    LitAction.tapSos,
    LitAction.holdSos,
    LitAction.shutter,
    LitAction.chooseAgency,
    LitAction.submit,
  }.contains(action);
}

/// The lessons, in the order a real report goes, on the real screens: SOS on
/// the map, the hold, the photo, the location, who should respond, the
/// details, send, the updates.
///
/// The captions are the supplied scripts, except where a clip is left out.
const List<LitLesson> kLitLessons = [
  LitLesson(
    id: '01',
    name: 'welcome',
    clip: '01_welcome',
    action: LitAction.start,
    pose: LitPose.wave,
    captionEn:
        "Hi! I'm Lit, your RepLiT guide. Let's practice sending a report. "
        'This is only a demo. No real alert will be sent. Tap Start Tutorial.',
    captionTl:
        'Kumusta! Ako si Lit, ang gabay mo sa RepLiT. Subukan nating gumawa '
        'ng report. Practice lang ito, kaya walang totoong alert na '
        'ipapadala. I-tap ang Start Tutorial.',
  ),
  LitLesson(
    id: '02',
    name: 'tap_sos',
    clip: '02_tap_sos',
    action: LitAction.tapSos,
    target: LitTargets.sosDisc,
    pose: LitPose.present,
    captionEn:
        'This is your home screen. When you need to report a fire, tap SOS '
        'at the bottom.',
    captionTl:
        'Ito ang home screen mo. Kapag may sunog kang ire-report, i-tap ang '
        'SOS sa ibaba.',
  ),
  LitLesson(
    id: '02',
    name: 'hold_sos',
    clip: '02_hold_sos',
    part: true,
    action: LitAction.holdSos,
    target: LitTargets.sosDial,
    pose: LitPose.present,
    captionEn:
        'This is the SOS screen. Press and hold the SOS button for two '
        'seconds. For practice, hold it now.',
    captionTl:
        'Ito ang SOS screen. Pindutin nang matagal ang SOS button nang '
        'dalawang segundo. Para sa practice, pindutin ito nang matagal '
        'ngayon.',
  ),
  LitLesson(
    id: '02',
    name: 'photo',
    clip: '02_photo',
    part: true,
    action: LitAction.shutter,
    target: LitTargets.shutter,
    pose: LitPose.present,
    captionEn:
        'RepLiT asks for one photo of the scene. For practice, take a photo '
        'of anything around you. It is never sent.',
    captionTl:
        'Isang litrato ng lugar ang hinihingi ng RepLiT. Para sa practice, '
        'kunan ng litrato ang kahit ano sa paligid mo. Hindi ito ipapadala.',
  ),
  LitLesson(
    id: '03',
    name: 'check_location',
    clip: '03_check_location',
    action: LitAction.read,
    target: LitTargets.location,
    pose: LitPose.pointUpperLeft,
    captionEn:
        'Check your location at the top. Your report carries where your '
        'phone is, found on its own, so responders can find you. Tap '
        'Continue.',
    captionTl:
        'Tingnan ang lokasyon mo sa itaas. Dala ng report mo kung nasaan ang '
        'phone mo, na kusang nahanap, para mahanap ka ng mga responder. '
        'I-tap ang Continue.',
  ),
  LitLesson(
    id: '04',
    name: 'select_organization',
    clip: '04_select_organization',
    action: LitAction.chooseAgency,
    target: LitTargets.medical,
    pose: LitPose.pointUpperRight,
    captionEn:
        'Next, choose the organization that will receive your report. For '
        'this practice, tap the highlighted organization.',
    captionTl:
        'Susunod, piliin ang organisasyong makakatanggap ng report mo. Para '
        'sa practice natin, i-tap ang naka-highlight na organisasyon.',
  ),
  LitLesson(
    id: '05',
    name: 'review_details',
    clip: '05_review_details',
    action: LitAction.read,
    target: LitTargets.form,
    pose: LitPose.review,
    captionEn:
        'Our sample report is ready. Check the location, selected '
        'organization, and report details. When everything looks right, tap '
        'Continue.',
    captionTl:
        'Handa na ang sample report natin. Tingnan ang lokasyon, napiling '
        'organisasyon, at mga detalye ng report. Kapag tama na, i-tap ang '
        'Continue.',
  ),
  LitLesson(
    id: '06',
    name: 'practice_submit',
    clip: '06_practice_submit',
    action: LitAction.submit,
    target: LitTargets.send,
    pose: LitPose.present,
    captionEn:
        'Now, tap Submit Practice Report. Remember, this is a demo. No real '
        'alert will be sent.',
    captionTl:
        'Ngayon, i-tap ang Submit Practice Report. Tandaan, practice lang '
        'ito. Walang totoong alert na ipapadala.',
  ),
  LitLesson(
    id: '07',
    name: 'follow_updates',
    clip: '07_follow_updates',
    action: LitAction.read,
    target: LitTargets.updates,
    pose: LitPose.present,
    captionEn:
        'Here, you can follow status updates. Reported means your report was '
        'received. En Route means responders are on the way. Tap Continue.',
    captionTl:
        'Dito mo makikita ang status updates. Ang Reported ay natanggap na '
        'ang report mo. Ang En Route ay papunta na ang responders. I-tap ang '
        'Continue.',
  ),
  LitLesson(
    id: '08',
    name: 'finish',
    clip: '08_finish',
    action: LitAction.finish,
    pose: LitPose.approve,
    captionEn:
        "You're ready! Report, check the details, and follow the updates. Tap "
        'Finish to return home. You can replay this tutorial anytime.',
    captionTl:
        'Handa ka na! Gumawa ng report, suriin ang detalye, at tingnan ang '
        'updates. I-tap ang Finish para bumalik sa home screen. Puwede mong '
        'ulitin ang tutorial anumang oras.',
  ),
];

/// How many lessons there are, for "2 of 8": 02 has three parts.
final int kLitLessonCount = kLitLessons.where((l) => !l.part).length;

/// Lit's words when a practice report has been "sent" (06's beat, before
/// the updates): "Practice report received. Nothing was sent." He says
/// them to the end, and a second later the updates follow (13 November
/// 2026: "lit needs to stop speaking first and pause for 1sec before you go
/// to step 7").
const String kReceivedClip = '06_report_received';

/// A clip of Lit's in [language], under assets/.
String litClipAsset(String clip, LitLanguage language) =>
    'tutorial/voice/${language.name}/$clip.mp3';
