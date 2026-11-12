/// The LIT tutorial's lessons: what each one teaches, the clip Lit says it
/// with in each language, its caption, and the pose Lit holds once the clip
/// is over.
///
/// Lessons are named by a stable id ("01".."08"), never by their place on
/// screen or their title: a clip stays with its lesson whatever the order.
/// The files are the supplied recordings, copied into assets/tutorial by
/// tool/tutorial/import_lit.dart.
library;

/// The tutorial's two languages: narration and captions switch together.
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

  /// Hold the practice SOS button for its two seconds.
  holdSos,

  /// Take the practice photo.
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

/// One lesson (or a part of one: the photo is the second half of 02).
class LitLesson {
  const LitLesson({
    required this.id,
    required this.name,
    required this.action,
    required this.pose,
    required this.captionEn,
    required this.captionTl,
    this.clip,
    this.part = false,
  });

  /// "01".."08": the lesson's number, and its clips'.
  final String id;

  /// The clip's file name without the language ("04_select_organization"),
  /// or null when the lesson is captioned without one (see [kMissingClips]).
  final String? clip;

  /// A short name, for tests and logs.
  final String name;
  final LitAction action;

  /// Lit's pose once the clip is over (or at once, without one). A pointing
  /// lesson turns this to the side its target is on.
  final LitPose pose;

  final String captionEn;
  final String captionTl;

  /// The second part of a lesson, sharing its number (the photo, in 02).
  final bool part;

  String caption(LitLanguage language) =>
      language == LitLanguage.tl ? captionTl : captionEn;

  /// The clip for [language], or null when this lesson has none.
  String? clipAsset(LitLanguage language) =>
      clip == null ? null : 'tutorial/voice/${language.name}/$clip.mp3';
}

/// The lessons, in the order the real report goes: SOS held, the photo, the
/// location, who should respond, the details, send, the updates.
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
    name: 'start_report',
    action: LitAction.holdSos,
    pose: LitPose.pointUpperLeft,
    captionEn:
        'This is the SOS screen: tap SOS at the bottom of any screen to open '
        'it. When you need to report a fire, press and hold the SOS button '
        'for two seconds. For practice, hold it now.',
    captionTl:
        'Ito ang SOS screen: i-tap ang SOS sa ibaba ng kahit anong screen '
        'para mabuksan ito. Kapag may sunog kang ire-report, pindutin nang '
        'matagal ang SOS button nang dalawang segundo. Para sa practice, '
        'pindutin ito nang matagal ngayon.',
  ),
  LitLesson(
    id: '02',
    name: 'photo',
    part: true,
    action: LitAction.shutter,
    pose: LitPose.pointUpperLeft,
    captionEn:
        'RepLiT asks for one photo of the scene. Tap the shutter to take a '
        'practice photo.',
    captionTl:
        'Isang litrato ng lugar ang hinihingi ng RepLiT. I-tap ang shutter '
        'para kumuha ng practice na litrato.',
  ),
  LitLesson(
    id: '03',
    name: 'check_location',
    action: LitAction.read,
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
    // Medical is in the right-hand column: Lit stands left and points up
    // to the right.
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
    pose: LitPose.pointUpperLeft,
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

/// How many lessons there are, for "2 of 8": the photo is part of 02.
final int kLitLessonCount = kLitLessons.where((l) => !l.part).length;

/// The supplied clips left out, and why: each says what the app does not.
/// Their lessons show accurate captions until new recordings replace them.
const Map<String, String> kMissingClips = {
  '02':
      'The clip says "Tap Report Incident". RepLiT has no such button: a '
      'report starts by holding SOS for two seconds.',
  '03':
      'The clip says the location "may be different from where you are". A '
      "report carries the phone's own location; there is no other to set.",
};
