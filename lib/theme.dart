import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from the "General User App v2" hand-off (Claude Design).
///
/// The rules the design holds to, which everything below encodes:
///   * one ground (#131313) with elevation expressed by translucent surfaces,
///     never by a lighter solid colour;
///   * every card edge is a 1px hairline, never a shadow;
///   * coral is the only accent, and glow is reserved for two moments — the
///     splash mark and the SOS button. Everywhere else it is flat;
///   * red (#FF544E) means live or destructive, green (#22C55E) means settled.
///
/// The v1 token names are all still here so the screens that have not been
/// reworked yet keep compiling — their values have simply moved to v2.
class AppColors {
  AppColors._();

  // ── ground ──────────────────────────────────────────────────────────────
  /// Outside the phone frame, and behind a camera viewfinder.
  static const Color canvas = Color(0xFF0B0B0B);

  /// Background/Island — pure black, for anything that must read as sitting
  /// on top of the app rather than in it (the coach marks' callouts).
  static const Color island = Color(0xFF000000);

  /// The screen background. Was #171717 in v1.
  static const Color background = Color(0xFF131313);

  /// Sheets, the nav bar, and anything that must be opaque over the map.
  static const Color surfaceSolid = Color(0xFF171717);

  /// Panels and placeholders. Kept solid for v1 screens; new work should use
  /// [glass], which is the same colour at the design's opacity.
  static const Color surface = Color(0xFF262626);
  static const Color glass = Color(0x8A262626); // rgba(38,38,38,.54)
  static const Color glassDim = Color(0x57262626); // rgba(38,38,38,.34)

  /// The raised pill behind the selected nav tab.
  static const Color raised = Color(0xFF303030);

  static const Color inputBg = Color(0xFF131313); // text field fill
  static const Color inputBorder = Color(0x59484847); // ~35% hairline

  // ── hairlines ───────────────────────────────────────────────────────────
  static const Color line = Color(0x59484847);
  static const Color lineStrong = Color(0x80484847);
  static const Color lineLight = Color(0x80ADAAAA);
  static const Color outline = Color(0x33FFFFFF);

  // ── ink ─────────────────────────────────────────────────────────────────
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color textSoft = Color(0xFFCFCFCF);
  static const Color label = Color(0xFFADAAAA);
  static const Color muted = Color(0xFF8A8A8A);

  /// Text/Placeholder — the tertiary grey at 75%, so an empty field reads
  /// as waiting rather than filled (COMPONENTS: Input).
  static const Color placeholder = Color(0xBFADAAAA);
  static const Color faint = Color(0xFF706E6E);
  static const Color darkText = Color(0xFF767575); // input placeholders

  // ── accent ──────────────────────────────────────────────────────────────
  static const Color gradientStart = Color(0xFFFF9066);

  /// v2 moves the button gradient's far stop from #EB4800 to #FF7943 — a
  /// shorter, warmer ramp. The old deep orange survives as [ember], which the
  /// design still uses for the "connected · location on" dot.
  static const Color gradientEnd = Color(0xFFFF7943);
  static const Color ember = Color(0xFFEB4800);

  static const Color accent = Color(0xFFFF9066);

  /// The wash behind a coral icon in a well. Named because it appears in
  /// every list row in the app.
  static const Color accentTint = Color(0x26FF9066);

  /// Text on the coral gradient. Dark brown, not black — it is what keeps the
  /// primary button from reading as a warning.
  static const Color accentText = Color(0xFF581A00);

  // ── meaning ─────────────────────────────────────────────────────────────
  static const Color live = Color(0xFFFF544E); // active incident, destructive
  static const Color ok = Color(0xFF22C55E); // resolved, verified, ready
  static const Color warn = Color(0xFFFACC15); // pending, needs attention

  // Interaction states from the COMPONENTS page. Hover and pressed are a
  // token overlay laid over the same fill, so a theme change carries them;
  // focus is a ring drawn outside the control, never a fill change.
  static const Color hover = Color(0x0FFFFFFF); // white 6%
  static const Color pressed = Color(0x1FFFFFFF); // white 12%
  static const Color focusRing = Color(0xE6FF9066); // coral 90%

  /// What a disabled control fades to (COMPONENTS: every disabled state).
  static const double disabledOpacity = 0.38;
  static const Color info = Color(0xFF6098D6);

  // ── agencies (REPLIT-OVERHAUL Figma, "Agency/*") ────────────────────────
  static const Color fire = Color(0xFFFF544E);
  static const Color medical = Color(0xFF35C77B);
  static const Color police = Color(0xFF5B93F5);
  static const Color barangay = Color(0xFFD98324);
  static const Color coastguard = Color(0xFF2DD4BF);

  /// Police markers and hotlines. Was violet in v1; the overhaul makes police
  /// blue everywhere, so this now simply names [police].
  static const Color crime = police;

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  /// The SOS button runs the same two stops on a diagonal.
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, Color(0xFFFF734E)],
  );

  /// One colour per public.area_status value, on the v2 palette. The two v10
  /// statuses (Master Context §2.5) follow fire out: the Post-Incident Report
  /// is owed, then filed and the incident closed. Both match the web consoles.
  static Color forStatus(String? status) => switch (status) {
    'pending' => warn,
    'verified' => const Color(0xFF42A5F5),
    'dispatched' => info,
    'en_route' => accent,
    'arrived' => live,
    'resolved' => ok,
    'post_incident_report' => const Color(0xFF2DD4BF),
    'closed' => const Color(0xFF16A34A),
    'rejected' => const Color(0xFF9E9E9E),
    'merged' => const Color(0xFF7E57C2),
    _ => muted,
  };

  /// Agency accent, matching the agency rows in the design. Fire volunteers
  /// keep the coral — they are this app's own crews — and BFP takes the
  /// design's fire red.
  static Color forAgency(String? agency) => switch (agency) {
    'fire_volunteer' => accent,
    'bfp' => fire,
    'police' => police,
    'medical' => medical,
    'barangay' => barangay,
    'coastguard' => coastguard,
    _ => muted,
  };
}

/// Corner radii the design uses. Nothing in the hand-off is square and nothing
/// is a stadium — everything is one of these four.
/// The two grounds the design ships: the dark one the app has always drawn,
/// and the light one from "GENERAL USER — MOBILE v2 · LIGHT".
///
/// The light values are not invented. The Figma resolves its colour variables
/// to the dark mode over the API, so each one here was read off the rendered
/// light frames by comparing them against the dark frames pixel for pixel —
/// four screens' worth, which agreed to the byte.
///
/// Two things deliberately do not change between themes: the coral gradient a
/// primary button is filled with, and the dark brown that sits on it. A button
/// that means "send help" should look the same in both.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.island,
    required this.background,
    required this.surfaceSolid,
    required this.surface,
    required this.glass,
    required this.glassDim,
    required this.raised,
    required this.inputBg,
    required this.line,
    required this.lineStrong,
    required this.onBackground,
    required this.textSoft,
    required this.label,
    required this.muted,
    required this.placeholder,
    required this.faint,
    required this.accent,
    required this.accentInk,
    required this.live,
    required this.ok,
    required this.warn,
    required this.lineLight,
    required this.hover,
    required this.pressed,
  });

  final Brightness brightness;

  // ground
  final Color canvas;
  final Color island;
  final Color background;
  final Color surfaceSolid;
  final Color surface;
  final Color glass;
  final Color glassDim;
  final Color raised;
  final Color inputBg;

  // edges
  final Color line;
  final Color lineStrong;

  // type
  final Color onBackground;
  final Color textSoft;
  final Color label;
  final Color muted;
  final Color placeholder;
  final Color faint;

  /// The accent as a fill — the gradient's head, unchanged in both themes.
  final Color accent;

  /// The accent as ink: coral is unreadable as text on a light ground, so the
  /// light theme darkens it to #A63A0A for labels, icons and strokes.
  final Color accentInk;

  final Color live;
  final Color ok;
  final Color warn;

  /// The brighter hairline the design uses on a photo or a map.
  final Color lineLight;

  /// Hover and pressed are an overlay over whatever is underneath: white on
  /// the dark ground, black on the light one, so both read as pressure.
  final Color hover;
  final Color pressed;

  /// The focus ring — the accent at 90%, drawn outside the control.
  Color get focusRing => accentInk.withValues(alpha: 0.9);

  bool get isLight => brightness == Brightness.light;

  /// The accent as a wash behind an icon or a selected chip.
  Color get accentTint => accentInk.withValues(alpha: 0.15);

  /// A hairline drawn over a photo or a map, where the ground is unknown.
  Color get outline =>
      isLight ? const Color(0x33000000) : const Color(0x33FFFFFF);

  /// Informational blue — never a status on its own, only a marker tint.
  Color get info => isLight ? const Color(0xFF2B6CB0) : const Color(0xFF6098D6);

  /// Agency colours. The dark values are the design's; the light ones are
  /// those same hues taken down until they carry as ink on a pale ground —
  /// derived, like `warn`, because no light frame shows an agency chip.
  Color get fire => live;
  Color get medical =>
      isLight ? const Color(0xFF0E7A45) : const Color(0xFF35C77B);
  Color get police =>
      isLight ? const Color(0xFF1E4FA8) : const Color(0xFF5B93F5);
  Color get barangay =>
      isLight ? const Color(0xFF8A5308) : const Color(0xFFD98324);
  Color get coastguard =>
      isLight ? const Color(0xFF0E6E66) : const Color(0xFF2DD4BF);
  Color get crime => police;

  /// What an incident's status looks like in this theme.
  Color forStatus(String? status) => switch (status) {
    'pending' => warn,
    'verified' => isLight ? const Color(0xFF1565C0) : const Color(0xFF42A5F5),
    'dispatched' => info,
    'en_route' => accentInk,
    'arrived' => live,
    'resolved' => ok,
    'post_incident_report' => coastguard,
    'closed' => isLight ? const Color(0xFF0F7A34) : const Color(0xFF16A34A),
    'rejected' => isLight ? const Color(0xFF6B6B6B) : const Color(0xFF9E9E9E),
    'merged' => isLight ? const Color(0xFF5B3EA8) : const Color(0xFF7E57C2),
    _ => muted,
  };

  /// Which agency an incident asked for.
  Color forAgency(String? agency) => switch (agency) {
    'fire_volunteer' => accentInk,
    'bfp' => fire,
    'police' => police,
    'medical' => medical,
    'barangay' => barangay,
    'coastguard' => coastguard,
    _ => muted,
  };

  /// Kept for the v1 screens: the grey an unfilled field's text used.
  Color get darkText => placeholder;

  /// The gradient's ends, for anything that needs them apart.
  Color get gradientStart => AppColors.gradientStart;
  Color get gradientEnd => AppColors.gradientEnd;

  /// The coral gradient. The same in both themes, by design.
  LinearGradient get accentGradient => AppColors.accentGradient;

  /// Text on the coral gradient.
  Color get accentText => AppColors.accentText;

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B0B0B),
    island: Color(0xFF000000),
    background: Color(0xFF131313),
    surfaceSolid: Color(0xFF171717),
    surface: Color(0xFF262626),
    glass: Color(0x8A262626),
    glassDim: Color(0x57262626),
    raised: Color(0xFF303030),
    inputBg: Color(0xFF131313),
    line: Color(0x59484847),
    lineStrong: Color(0x80484847),
    onBackground: Color(0xFFFFFFFF),
    textSoft: Color(0xFFCFCFCF),
    label: Color(0xFFADAAAA),
    muted: Color(0xFF8A8A8A),
    placeholder: Color(0xBFADAAAA),
    faint: Color(0xFF706E6E),
    accent: Color(0xFFFF9066),
    accentInk: Color(0xFFFF9066),
    live: Color(0xFFFF544E),
    ok: Color(0xFF22C55E),
    warn: Color(0xFFFACC15),
    lineLight: Color(0x80ADAAAA),
    hover: Color(0x0FFFFFFF),
    pressed: Color(0x1FFFFFFF),
  );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFE4E2DE),
    island: Color(0xFF000000),
    background: Color(0xFFEEEDEA),
    surfaceSolid: Color(0xFFF3F3F1),
    surface: Color(0xFFFCFCFC),
    glass: Color(0xFFFCFCFC),
    glassDim: Color(0xFFF8F7F6),
    raised: Color(0xFFE5E4E1),
    inputBg: Color(0xFFFCFCFC),
    line: Color(0xFFDDDCDB),
    lineStrong: Color(0xFFD0D0CC),
    onBackground: Color(0xFF17140F),
    textSoft: Color(0xFF423C35),
    label: Color(0xFF5B534A),
    muted: Color(0xFF6E665C),
    placeholder: Color(0xBF5B534A),
    faint: Color(0xFF918B84),
    // On a pale ground the coral is the ink, not the fill: every accent pixel
    // in the light frames reads #A63A0A. The fill survives only where the
    // gradient is drawn — a primary button, the SOS disc — and that gradient
    // is shared between the themes.
    accent: Color(0xFFA63A0A),
    accentInk: Color(0xFFA63A0A),
    live: Color(0xFFB01712),
    ok: Color(0xFF106633),
    // Not sampled: no light frame shows a pending state. Darkened to the same
    // degree as live and settled were, so it carries on a pale ground.
    warn: Color(0xFF8A6100),
    lineLight: Color(0x805B534A),
    hover: Color(0x0F000000),
    pressed: Color(0x1F000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 ? this : (other as AppPalette? ?? this);
}

/// The palette in force. Anything drawn outside a build — a painter, a static
/// helper — takes one as an argument rather than reaching for this.
extension PaletteContext on BuildContext {
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

class AppRadius {
  AppRadius._();

  static const double chip = 11;
  static const double control = 12; // rows, fields, every button
  static const double card = 14; // list cards, notices
  static const double panel = 16; // grouped panels, selection cards
  static const double sheet = 20; // bottom sheets, screen frame
}

/// The type ramp. Weights carry more meaning than sizes here: w900 uppercase
/// names a thing, w300 is prose, and a 10px w700 uppercase "eyebrow" labels
/// every section.
class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 34 / 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.3,
    color: AppColors.onBackground,
  );
  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 26 / 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.9,
    color: AppColors.onBackground,
  );
  static const TextStyle screenTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AppColors.onBackground,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AppColors.onBackground,
  );
  static const TextStyle rowTitle = TextStyle(
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.onBackground,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w300,
    color: AppColors.label,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  static const TextStyle eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: AppColors.faint,
  );
  static const TextStyle tag = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
  );
  static const TextStyle action = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: AppColors.accentText,
  );
  static const TextStyle numeral = TextStyle(
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    color: AppColors.onBackground,
  );

  // ── REPLIT-OVERHAUL additions ───────────────────────────────────────────
  // The Figma's named text styles that the v2 ramp above did not have. Names
  // follow the Figma ("Type/Heading 1" → heading1) so a spec reads straight
  // across. The design sets everything in Inter; until the font is bundled
  // these fall back to the platform face at the same size and weight.
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.1,
    color: AppColors.onBackground,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 26,
    height: 28 / 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
    color: AppColors.onBackground,
  );

  /// "Type/Title" — 17px, the sheet and card-header size.
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 20 / 17,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.onBackground,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    height: 18 / 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.onBackground,
  );
  static const TextStyle cardTitleSm = TextStyle(
    fontSize: 13,
    height: 15 / 13,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: AppColors.onBackground,
  );

  /// "Type/Row title" — the 13px list-row name ([rowTitle] is the 12px one).
  static const TextStyle rowTitleLg = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.onBackground,
  );
  static const TextStyle rowValue = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textSoft,
  );
  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.label,
  );

  /// "Type/Meta" — 12px secondary line. ([meta] above is the 11px caption.)
  static const TextStyle detail = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  static const TextStyle captionSm = TextStyle(
    fontSize: 10,
    height: 13 / 10,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.onBackground,
  );

  static const TextStyle labelSm = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.textSoft,
  );
  static const TextStyle numeralSm = TextStyle(
    fontSize: 17,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.onBackground,
  );
  static const TextStyle numeralXl = TextStyle(
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.6,
    color: AppColors.onBackground,
  );
  static const TextStyle dial = TextStyle(
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: AppColors.onBackground,
  );

  /// Type/Onboarding heading — the one line that names each tour step.
  static const TextStyle tourHeading = TextStyle(
    fontSize: 26,
    height: 31 / 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.7,
    color: AppColors.onBackground,
  );

  /// Type/Body large — tour prose, a size up from the rest of the app.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w300,
    color: AppColors.textSoft,
  );

  /// Type/Button large — the tour's full-width call to action.
  static const TextStyle actionLarge = TextStyle(
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
    color: AppColors.accentText,
  );

  static const TextStyle input = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    color: AppColors.onBackground,
  );
}

/// Light status-bar glyphs on the dark ground.
/// The type ramp in the palette's ink.
///
/// Same metrics as [AppText] — only the colour moves between themes, so a
/// screen reads `context.type.cardTitle` and gets the right one either way.
/// [AppText] itself keeps the dark values, for the screens not yet moved over
/// and for anything that needs a const style.
@immutable
class AppType {
  const AppType(this._p);

  final AppPalette _p;

  TextStyle get display => AppText.display.copyWith(color: _p.onBackground);
  TextStyle get title => AppText.title.copyWith(color: _p.onBackground);
  TextStyle get screenTitle =>
      AppText.screenTitle.copyWith(color: _p.onBackground);
  TextStyle get cardTitle => AppText.cardTitle.copyWith(color: _p.onBackground);
  TextStyle get rowTitle => AppText.rowTitle.copyWith(color: _p.onBackground);
  TextStyle get body => AppText.body.copyWith(color: _p.label);
  TextStyle get meta => AppText.meta.copyWith(color: _p.muted);
  TextStyle get eyebrow => AppText.eyebrow.copyWith(color: _p.faint);
  TextStyle get tag => AppText.tag;
  TextStyle get action => AppText.action.copyWith(color: _p.accentText);
  TextStyle get numeral => AppText.numeral.copyWith(color: _p.onBackground);
  TextStyle get heading1 => AppText.heading1.copyWith(color: _p.onBackground);
  TextStyle get heading2 => AppText.heading2.copyWith(color: _p.onBackground);
  TextStyle get headline => AppText.headline.copyWith(color: _p.onBackground);
  TextStyle get subtitle => AppText.subtitle.copyWith(color: _p.onBackground);
  TextStyle get cardTitleSm =>
      AppText.cardTitleSm.copyWith(color: _p.onBackground);
  TextStyle get rowTitleLg =>
      AppText.rowTitleLg.copyWith(color: _p.onBackground);
  TextStyle get rowValue => AppText.rowValue.copyWith(color: _p.textSoft);
  TextStyle get bodySm => AppText.bodySm.copyWith(color: _p.label);
  TextStyle get detail => AppText.detail.copyWith(color: _p.muted);
  TextStyle get caption => AppText.caption.copyWith(color: _p.muted);
  TextStyle get captionSm => AppText.captionSm.copyWith(color: _p.muted);
  TextStyle get label => AppText.label.copyWith(color: _p.onBackground);
  TextStyle get labelSm => AppText.labelSm.copyWith(color: _p.textSoft);
  TextStyle get numeralSm => AppText.numeralSm.copyWith(color: _p.onBackground);
  TextStyle get numeralXl => AppText.numeralXl.copyWith(color: _p.onBackground);
  TextStyle get dial => AppText.dial.copyWith(color: _p.onBackground);
  TextStyle get tourHeading =>
      AppText.tourHeading.copyWith(color: _p.onBackground);
  TextStyle get bodyLarge => AppText.bodyLarge.copyWith(color: _p.textSoft);
  TextStyle get actionLarge =>
      AppText.actionLarge.copyWith(color: _p.accentText);
  TextStyle get input => AppText.input.copyWith(color: _p.onBackground);
}

/// The type ramp in force, alongside [PaletteContext.pal].
extension TypeContext on BuildContext {
  AppType get type => AppType(pal);
}

/// Light status-bar glyphs on the dark ground; dark ones on the light.
SystemUiOverlayStyle overlayFor(AppPalette pal) => SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: pal.isLight ? Brightness.dark : Brightness.light,
  statusBarBrightness: pal.brightness,
  systemNavigationBarColor: pal.surfaceSolid,
  systemNavigationBarIconBrightness: pal.isLight
      ? Brightness.dark
      : Brightness.light,
);

ThemeData buildAppTheme([AppPalette pal = AppPalette.dark]) {
  final base = pal.isLight
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);

  // The Input component draws its resting edge at 1px and every state that
  // means something — filled, focused, in error — at 1.5px.
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  final type = AppType(pal);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[pal],
    scaffoldBackgroundColor: pal.background,
    canvasColor: pal.background,
    colorScheme: base.colorScheme.copyWith(
      surface: pal.background,
      primary: pal.accent,
      onPrimary: AppColors.accentText,
      secondary: AppColors.gradientEnd,
      error: pal.live,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: pal.onBackground,
      displayColor: pal.onBackground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlayFor(pal),
      titleTextStyle: type.screenTitle,
      iconTheme: IconThemeData(color: pal.onBackground, size: 20),
    ),
    dividerTheme: DividerThemeData(color: pal.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pal.inputBg,
      hintStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: pal.placeholder,
      ),
      labelStyle: type.eyebrow,
      floatingLabelStyle: type.eyebrow.copyWith(color: pal.accentInk),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: fieldBorder(pal.line),
      enabledBorder: fieldBorder(pal.line),
      focusedBorder: fieldBorder(pal.accent, 1.5),
      errorBorder: fieldBorder(pal.live, 1.5),
      focusedErrorBorder: fieldBorder(pal.live, 1.5),
      errorStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: pal.live,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: pal.raised,
      contentTextStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: pal.onBackground,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.surfaceSolid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pal.surfaceSolid,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: pal.accentInk,
      linearTrackColor: pal.line,
      circularTrackColor: pal.line,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? pal.surfaceSolid : pal.label,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? pal.accent : pal.glass,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: pal.accentInk,
      selectionColor: Color(0x40FF9066),
      selectionHandleColor: pal.accentInk,
    ),
    cardTheme: CardThemeData(
      color: pal.glass,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pal.accent,
        foregroundColor: AppColors.accentText,
        minimumSize: Size(double.infinity, 52),
        elevation: 0,
        textStyle: type.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pal.accent,
        foregroundColor: AppColors.accentText,
        minimumSize: Size(double.infinity, 52),
        textStyle: type.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.textSoft,
        backgroundColor: pal.glass,
        minimumSize: Size(0, 48),
        side: BorderSide(color: pal.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: pal.accentInk),
    ),
  );
}
