import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from the "General User App v2" hand-off (Claude Design).
///
/// The rules the design holds to, which the widgets below encode:
///   * one background (#131313) with elevation expressed by translucent
///     surfaces, never by a lighter solid colour;
///   * every card edge is an inset 1px hairline, never a border or shadow;
///   * coral is the only accent, and glow is reserved for two moments — the
///     splash mark and the SOS button. Everywhere else it is flat;
///   * red (#FF544E) means live or destructive; green (#22C55E) means settled.
abstract final class AppColors {
  // ── ground ──────────────────────────────────────────────────────────────
  static const canvas = Color(0xFF0B0B0B); // outside the phone frame
  static const bg = Color(0xFF131313); // screen background
  static const field = Color(0xFF131313); // input wells

  /// Card / row surfaces. The design writes these as rgba over the ground;
  /// Flutter composites the same way, so the alpha is kept.
  static const surface = Color(0x8A262626); // rgba(38,38,38,.54)
  static const surfaceDim = Color(0x57262626); // rgba(38,38,38,.34)
  static const surfaceSolid = Color(0xFF171717); // sheets, nav bar
  static const surfaceRaised = Color(0xFF303030); // selected nav pill

  // ── hairlines ───────────────────────────────────────────────────────────
  static const line = Color(0x59484847); // rgba(72,72,71,.35)
  static const lineStrong = Color(0x80484847);
  static const lineLight = Color(0x80ADAAAA); // rgba(173,170,170,.5)

  // ── ink ─────────────────────────────────────────────────────────────────
  static const text = Color(0xFFFFFFFF);
  static const textSoft = Color(0xFFCFCFCF);
  static const label = Color(0xFFADAAAA);
  static const muted = Color(0xFF8A8A8A);
  static const faint = Color(0xFF706E6E);

  // ── accent ──────────────────────────────────────────────────────────────
  static const accent = Color(0xFFFF9066);
  static const accentDeep = Color(0xFFFF7943);
  /// Text sitting on the coral gradient. Dark brown, not black — the design is
  /// specific about it and it is what keeps the button from looking like a
  /// warning.
  static const onAccent = Color(0xFF581A00);

  static const live = Color(0xFFFF544E); // active incident, destructive
  static const ok = Color(0xFF22C55E); // resolved, verified, ready
  static const info = Color(0xFF6098D6);
  static const crime = Color(0xFF8A38F5);
  static const ember = Color(0xFFEB4800); // connected dot on the SOS screen

  static const accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [accent, accentDeep],
  );

  /// The SOS button uses a diagonal of the same two coral stops.
  static const sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFFF734E)],
  );

  // One colour per public.area_status value. Progression reads warm-to-cool:
  // awaiting review, verified, then responders closing in, then resolved.
  // Remapped onto the design palette — the old Material blues had no place in
  // a dark coral system.
  static const statusPending = Color(0xFFEAB308);
  static const statusVerified = Color(0xFF42A5F5);
  static const statusDispatched = info;
  static const statusEnRoute = accent;
  static const statusArrived = live;
  static const statusResolved = ok;
  static const statusRejected = Color(0xFF9E9E9E);
  static const statusMerged = Color(0xFF7E57C2);

  static Color forStatus(String status) {
    return switch (status) {
      'pending' => statusPending,
      'verified' => statusVerified,
      'dispatched' => statusDispatched,
      'en_route' => statusEnRoute,
      'arrived' => statusArrived,
      'resolved' => statusResolved,
      'rejected' => statusRejected,
      'merged' => statusMerged,
      _ => muted,
    };
  }

  /// Agency accent, matching the incident-type cards in the design.
  static Color forAgency(String? agency) {
    return switch (agency) {
      'fire_volunteer' => accent,
      'bfp' => live,
      'police' => crime,
      'medical' => ok,
      'barangay' => label,
      _ => muted,
    };
  }
}

/// Corner radii the design uses. Nothing in the hand-off is square and nothing
/// is a stadium — everything is one of these four.
abstract final class AppRadius {
  static const chip = 11.0;
  static const control = 12.0; // rows, fields, small buttons
  static const card = 14.0; // list cards, primary buttons
  static const panel = 16.0; // grouped panels, selection cards
  static const sheet = 20.0; // bottom sheets, screen frame
}

/// The type ramp. Weights matter more than sizes here: the design leans on
/// w900 uppercase for anything that names a thing, w300 for prose, and a w700
/// 10px uppercase "eyebrow" for every section label.
abstract final class AppText {
  static const display = TextStyle(
    fontSize: 32,
    height: 34 / 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.3,
    color: AppColors.text,
  );
  static const title = TextStyle(
    fontSize: 24,
    height: 26 / 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.9,
    color: AppColors.text,
  );
  static const screenTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const cardTitle = TextStyle(
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const rowTitle = TextStyle(
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w300,
    color: AppColors.label,
  );
  static const meta = TextStyle(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  /// The 10px uppercase section label used everywhere in the design.
  static const eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: AppColors.faint,
  );
  static const tag = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
  );
  /// Label on a filled primary button.
  static const action = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: AppColors.onAccent,
  );
  static const numeral = TextStyle(
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    color: AppColors.text,
  );
}

abstract final class AppTheme {
  /// Light status-bar glyphs on the dark ground, and no system nav divider.
  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surfaceSolid,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentDeep,
      surface: AppColors.bg,
      onSurface: AppColors.text,
      error: AppColors.live,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: AppText.screenTitle,
        iconTheme: IconThemeData(color: AppColors.text, size: 20),
      ),
      textTheme: const TextTheme(
        headlineLarge: AppText.display,
        headlineMedium: AppText.title,
        titleMedium: AppText.screenTitle,
        titleSmall: AppText.cardTitle,
        bodyMedium: AppText.body,
        bodySmall: AppText.meta,
        labelSmall: AppText.eyebrow,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0x73ADAAAA),
        ),
        labelStyle: AppText.eyebrow,
        floatingLabelStyle: AppText.eyebrow.copyWith(color: AppColors.accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: _fieldBorder(AppColors.line),
        enabledBorder: _fieldBorder(AppColors.line),
        focusedBorder: _fieldBorder(const Color(0x73FF9066)),
        errorBorder: _fieldBorder(AppColors.live),
        focusedErrorBorder: _fieldBorder(AppColors.live),
        errorStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.live,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
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
        showDragHandle: false,
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
              : AppColors.surface,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x40FF9066),
        selectionHandleColor: AppColors.accent,
      ),
      // Buttons are built from AppButton below; these keep any stray Material
      // button from breaking the palette.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          textStyle: AppText.action,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: color),
  );
}
