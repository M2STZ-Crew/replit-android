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
  static const TextStyle input = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    color: AppColors.onBackground,
  );
}

/// Light status-bar glyphs on the dark ground.
const SystemUiOverlayStyle kSystemOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.surfaceSolid,
  systemNavigationBarIconBrightness: Brightness.light,
);

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: color),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.background,
      primary: AppColors.accent,
      onPrimary: AppColors.accentText,
      secondary: AppColors.gradientEnd,
      error: AppColors.live,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.onBackground,
      displayColor: AppColors.onBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: kSystemOverlay,
      titleTextStyle: AppText.screenTitle,
      iconTheme: IconThemeData(color: AppColors.onBackground, size: 20),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBg,
      hintStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0x73ADAAAA),
      ),
      labelStyle: AppText.eyebrow,
      floatingLabelStyle: AppText.eyebrow.copyWith(color: AppColors.accent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: fieldBorder(AppColors.line),
      enabledBorder: fieldBorder(AppColors.line),
      focusedBorder: fieldBorder(const Color(0x73FF9066)),
      errorBorder: fieldBorder(AppColors.live),
      focusedErrorBorder: fieldBorder(AppColors.live),
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.live,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.raised,
      contentTextStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.onBackground,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceSolid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceSolid,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.line,
      circularTrackColor: AppColors.line,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.surfaceSolid
            : AppColors.label,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.glass,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x40FF9066),
      selectionHandleColor: AppColors.accent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.glass,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentText,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        textStyle: AppText.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentText,
        minimumSize: const Size(double.infinity, 52),
        textStyle: AppText.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSoft,
        backgroundColor: AppColors.glass,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
  );
}
