import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/design.dart';
import 'map_screen.dart';

/// Whether the resident has been shown the tour, and the map's coach marks.
///
/// Both are kept on the phone: nothing about a tutorial belongs on the server,
/// and a reinstall showing it again is the right behaviour anyway.
abstract final class Tour {
  static const String _tourKey = 'tour_seen_v1';
  static const String _coachKey = 'map_coach_seen_v1';

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_tourKey) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_tourKey, true);

  static Future<bool> coachMarksSeen() async =>
      (await SharedPreferences.getInstance()).getBool(_coachKey) ?? false;

  static Future<void> markCoachMarksSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_coachKey, true);
}

/// "GENERAL USER — ONBOARDING" (frames T1–T7): Lit the firefly walks a new
/// resident through the one thing they must be able to do under stress — hold
/// SOS — and through the three ideas that make the rest of the app legible:
/// who comes, how reports become one Area, and why a neighbour gets asked.
///
/// Every claim here is one the system keeps: the hold really is three seconds,
/// the photo really is required, 300 m really is the corroboration radius.
/// The practice step sends nothing, and says so twice.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinish});

  /// Where to go when the tour ends. Defaults to the map.
  final VoidCallback? onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await Tour.markSeen();
    if (!mounted) return;
    final onFinish = widget.onFinish;
    if (onFinish != null) {
      onFinish();
      return;
    }
    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final steps = <Widget>[
      _Welcome(onStart: () => _go(1), onSkip: _finish),
      _HoldSos(
        step: 1,
        onBack: () => _go(0),
        onSkip: _finish,
        onNext: () => _go(2),
      ),
      _WhoAndPhoto(
        step: 2,
        onBack: () => _go(1),
        onSkip: _finish,
        onNext: () => _go(3),
      ),
      _Areas(
        step: 3,
        onBack: () => _go(2),
        onSkip: _finish,
        onNext: () => _go(4),
      ),
      _Nearby(
        step: 4,
        onBack: () => _go(3),
        onSkip: _finish,
        onNext: () => _go(5),
      ),
      _Practice(step: 5, onBack: () => _go(4), onNext: () => _go(6)),
      _Ready(step: 6, onBack: () => _go(5), onDone: _finish),
    ];
    return Scaffold(
      backgroundColor: context.pal.background,
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          for (final (i, step) in steps.indexed)
            // Only the visible page animates; the practice dial off-screen has
            // no business running a ticker.
            _PageHost(active: i == _index, child: step),
        ],
      ),
    );
  }
}

class _PageHost extends StatelessWidget {
  const _PageHost({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: active, child: child);
}

// ── shared chrome ──────────────────────────────────────────────────────────

/// Back, the six-segment progress and Skip: the top bar of T2–T7.
class _TourBar extends StatelessWidget {
  const _TourBar({required this.step, this.onBack, this.onSkip});

  /// 1-based, of six.
  final int step;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: context.pal.onBackground,
                    iconSize: 26,
                    tooltip: 'Back',
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 6; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Semantics(
                    label: i == step ? 'Step $step of 6' : null,
                    child: Container(
                      width: 22,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? context.pal.accent
                            : context.pal.lineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: onSkip == null
                ? null
                : TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: context.pal.label,
                    ),
                    child: Text('Skip', style: context.type.label),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The body every step shares: a stage that illustrates the point, the line
/// that names it, the prose that explains it, and what to press.
class _TourStep extends StatelessWidget {
  const _TourStep({
    required this.step,
    required this.stage,
    required this.title,
    required this.body,
    required this.actions,
    this.onBack,
    this.onSkip,
  });

  final int step;
  final Widget stage;
  final String title;
  final String body;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _TourBar(step: step, onBack: onBack, onSkip: onSkip),
          // The stage is a picture and the copy is the point: at a large text
          // scale the copy wins the space and this middle scrolls, rather than
          // the illustration pushing the words off the screen. What to press
          // stays where it was, because a tour you have to scroll to leave is
          // a tour that traps people.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(child: stage),
                  const SizedBox(height: 22),
                  Text(title, style: context.type.tourHeading),
                  const SizedBox(height: 8),
                  Text(body, style: context.type.bodyLarge),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lit, at the size a given step draws him.
class _Lit extends StatelessWidget {
  const _Lit({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    Art.lit,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

/// A demo card: the surface every stage illustration sits on.
class _Demo extends StatelessWidget {
  const _Demo({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Panel(radius: AppRadius.card, padding: padding, child: child);
}

// ── T1 · Welcome ───────────────────────────────────────────────────────────

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.onSkip});

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(child: _Lit(height: 310)),
                  const SizedBox(height: 24),
                  Text(
                    "Hi, I'm Lit.",
                    textAlign: TextAlign.center,
                    style: context.type.tourHeading,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "I'm a firefly. I'll show you how to report an emergency "
                    'here — about a minute.',
                    textAlign: TextAlign.center,
                    style: context.type.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton('Show me around', large: true, onPressed: onStart),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: context.pal.label,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Skip for now', style: context.type.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── T2 · Hold SOS ──────────────────────────────────────────────────────────

class _HoldSos extends StatefulWidget {
  const _HoldSos({
    required this.step,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  State<_HoldSos> createState() => _HoldSosState();
}

class _HoldSosState extends State<_HoldSos>
    with SingleTickerProviderStateMixin {
  // The demo dial fills over the same three seconds the real one takes, then
  // rests a moment and repeats — the point of the step is the duration.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(period: const Duration(milliseconds: 4200));

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TourStep(
      step: widget.step,
      onBack: widget.onBack,
      onSkip: widget.onSkip,
      title: 'Hold SOS for three seconds',
      body:
          'A tap sends nothing. Holding is what starts a report, so it '
          "can't happen by accident in your pocket.",
      stage: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Lit(height: 145),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => _HoldDial(
                  size: 180,
                  progress: _hold.value,
                  fingertip: true,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [AppButton('Next', large: true, onPressed: widget.onNext)],
    );
  }
}

/// The SOS dial as the tour draws it: a track, the elapsed arc, the coral disc
/// and — in the demo steps — a fingertip resting on it.
class _HoldDial extends StatelessWidget {
  const _HoldDial({
    required this.size,
    required this.progress,
    this.fingertip = false,
    this.label,
    this.glow = false,
  });

  final double size;
  final double progress;
  final bool fingertip;
  final String? label;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final disc = size * 0.68;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.pal.accent.withValues(alpha: 0.22),
                    context.pal.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              track: context.pal.lineStrong,
              elapsed: context.pal.accentInk,
            ),
          ),
          Container(
            width: disc,
            height: disc,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SOS',
                  style: context.type.display.copyWith(
                    color: AppColors.accentText,
                    fontSize: disc * 0.157,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    label!,
                    style: context.type.label.copyWith(
                      color: AppColors.accentText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (fingertip)
            Positioned(
              bottom: size * 0.13,
              child: Container(
                width: size * 0.29,
                height: size * 0.29,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.pal.onBackground.withValues(alpha: 0.16),
                  border: Border.all(
                    color: context.pal.onBackground.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.elapsed,
  });

  final double progress;
  final Color track;
  final Color elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = track;
    final elapsedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = elapsed;
    canvas.drawCircle(centre, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -1.5707963267948966, // 12 o'clock
        6.283185307179586 * progress.clamp(0.0, 1.0),
        false,
        elapsedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.elapsed != elapsed;
}

// ── T3 · Who and photo ─────────────────────────────────────────────────────

class _WhoAndPhoto extends StatelessWidget {
  const _WhoAndPhoto({
    required this.step,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  static List<({String label, String art, Color tint})> _agenciesFor(
    AppPalette pal,
  ) => [
    (label: 'Fire', art: Art.agFire, tint: pal.fire),
    (label: 'Police', art: Art.agPolice, tint: pal.police),
    (label: 'Medical', art: Art.agMedical, tint: pal.medical),
    (label: 'Barangay', art: Art.agBarangay, tint: pal.barangay),
  ];

  @override
  Widget build(BuildContext context) {
    return _TourStep(
      step: step,
      onBack: onBack,
      onSkip: onSkip,
      title: 'Pick who should come, then take one photo',
      body:
          'Fire, police, medical, barangay — one or several. The photo is '
          'required: it tells the responders what they are driving into.',
      stage: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Lit(height: 114),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // An illustration, so it scales down as one rather than
                // letting a long agency name at a large text size push the
                // row off the screen.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      for (final a in _agenciesFor(context.pal))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconWell(
                                tint: a.tint,
                                asset: a.art,
                                size: 52,
                                glyph: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.label,
                                style: context.type.captionSm.copyWith(
                                  color: context.pal.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Demo(
                  child: Row(
                    children: [
                      IconWell(
                        tint: context.pal.accent,
                        icon: Icons.photo_camera_outlined,
                        size: 46,
                        glyph: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'One photo of the scene',
                              style: context.type.rowTitleLg,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Required — there is no skip',
                              style: context.type.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [AppButton('Next', large: true, onPressed: onNext)],
    );
  }
}

// ── T4 · Areas ─────────────────────────────────────────────────────────────

class _Areas extends StatelessWidget {
  const _Areas({
    required this.step,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _TourStep(
      step: step,
      onBack: onBack,
      onSkip: onSkip,
      title: 'Reports near each other become one',
      body:
          'If a neighbour reports the same fire, RepLiT groups it with yours '
          'into a single Area — so responders see one incident, not five.',
      stage: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TourMap(
            height: 168,
            chip: '3 reports',
            children: [
              _Blob(left: 0.30, top: 0.34, diameter: 108, ring: true),
              _Blob(left: 0.30, top: 0.34, diameter: 11),
              _Blob(left: 0.41, top: 0.27, diameter: 11),
              _Blob(left: 0.24, top: 0.46, diameter: 11),
            ],
          ),
          const SizedBox(height: 10),
          _Demo(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Area confidence',
                        style: context.type.rowTitle,
                      ),
                    ),
                    Text(
                      'Medium',
                      style: context.type.labelSm.copyWith(
                        color: context.pal.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i < 2
                                ? context.pal.accent
                                : context.pal.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [AppButton('Next', large: true, onPressed: onNext)],
    );
  }
}

// ── T5 · 300 m ─────────────────────────────────────────────────────────────

class _Nearby extends StatelessWidget {
  const _Nearby({
    required this.step,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _TourStep(
      step: step,
      onBack: onBack,
      onSkip: onSkip,
      title: 'You may be asked to confirm',
      body:
          'When something is reported within 300 metres of you, RepLiT asks '
          'one question. Answering makes the report more certain.',
      stage: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TourMap(
            height: 140,
            chip: '300 m around you',
            children: [
              _Blob(left: 0.32, top: 0.42, diameter: 126, ring: true),
              _Blob(left: 0.32, top: 0.42, diameter: 13, live: true),
              _Blob(left: 0.44, top: 0.30, diameter: 13),
            ],
          ),
          const SizedBox(height: 10),
          _Demo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Do you see it too?', style: context.type.rowTitleLg),
                const SizedBox(height: 3),
                Text(
                  'Fire reported 180 m from you',
                  style: context.type.caption,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _GhostButton(
                        'Yes, report it',
                        tone: context.pal.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _GhostButton('Ignore')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [AppButton('Next', large: true, onPressed: onNext)],
    );
  }
}

/// A button drawn for illustration only — it is part of a picture of the app,
/// so it does not take a tap.
class _GhostButton extends StatelessWidget {
  const _GhostButton(this.label, {this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colour = tone ?? context.pal.label;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: tone == null
            ? context.pal.glass
            : colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: tone == null
              ? context.pal.line
              : colour.withValues(alpha: 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: Text(label, style: context.type.labelSm.copyWith(color: colour)),
    );
  }
}

/// The tour's map picture: the design's Pasay plate with the shapes the step
/// is explaining drawn over it.
class _TourMap extends StatelessWidget {
  const _TourMap({
    required this.height,
    required this.chip,
    required this.children,
  });

  final double height;
  final String chip;
  final List<_Blob> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  Art.tourMap,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: context.pal.background.withValues(alpha: 0.35),
                ),
              ),
              for (final blob in children)
                blob.at(Size(box.maxWidth, box.maxHeight), context.pal),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: context.pal.background.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: context.pal.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chip,
                    style: context.type.caption.copyWith(
                      color: context.pal.onBackground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A report dot, or the ring around an Area. Its place is a fraction of the
/// picture, so the shapes hold their arrangement at any width.
class _Blob {
  const _Blob({
    required this.left,
    required this.top,
    required this.diameter,
    this.ring = false,
    this.live = false,
  });

  final double left;
  final double top;
  final double diameter;
  final bool ring;
  final bool live;

  Widget at(Size box, AppPalette pal) {
    final colour = live ? pal.onBackground : pal.accentInk;
    return Positioned(
      left: box.width * left - diameter / 2,
      top: box.height * top - diameter / 2,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring ? pal.accentTint : colour,
          border: Border.all(
            color: ring
                ? pal.accentInk.withValues(alpha: 0.55)
                : pal.background.withValues(alpha: 0.8),
            width: ring ? 1.5 : 2,
          ),
        ),
      ),
    );
  }
}

// ── T6 · Practice ──────────────────────────────────────────────────────────

class _Practice extends StatefulWidget {
  const _Practice({
    required this.step,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice>
    with SingleTickerProviderStateMixin {
  // Three seconds, the same as the real dial (lib/screens/home_screen.dart).
  late final AnimationController _hold =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_done) {
          setState(() => _done = true);
          HapticFeedback.heavyImpact();
        }
      });

  bool _done = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _start() {
    if (_done) return;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _stop() {
    if (_done) return;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _TourBar(step: widget.step, onBack: widget.onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scaled down rather than truncated: "nothing is sent" is
                  // the one line on this screen that must stay readable at
                  // every text size.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
                      decoration: BoxDecoration(
                        color: context.pal.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(
                          color: context.pal.accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.pal.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Practice — nothing is sent',
                            style: context.type.label.copyWith(
                              color: context.pal.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTapDown: (_) => _start(),
                    onTapUp: (_) => _stop(),
                    onTapCancel: _stop,
                    child: Semantics(
                      button: true,
                      label:
                          'Practice SOS dial. Hold for three seconds. '
                          'Nothing is sent.',
                      child: AnimatedBuilder(
                        animation: _hold,
                        builder: (context, _) => _HoldDial(
                          size: 260,
                          progress: _hold.value,
                          glow: true,
                          label: _done ? 'done' : 'hold',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _done
                        ? "That's it. Nothing was sent — this was practice."
                        : 'Keep your finger down until the ring closes.',
                    textAlign: TextAlign.center,
                    style: context.type.bodyLarge.copyWith(
                      color: context.pal.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton("I've got it", large: true, onPressed: widget.onNext),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: widget.onNext,
                  style: TextButton.styleFrom(
                    foregroundColor: context.pal.label,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Skip practice', style: context.type.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── T7 · Ready ─────────────────────────────────────────────────────────────

class _Ready extends StatelessWidget {
  const _Ready({
    required this.step,
    required this.onBack,
    required this.onDone,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onDone;

  static const List<String> _recap = [
    'Hold SOS for three seconds',
    'One photo goes with every report',
    'Answer when a report lands near you',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _TourBar(step: step, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const _Lit(height: 134),
                  const SizedBox(height: 16),
                  Text(
                    "You're ready",
                    textAlign: TextAlign.center,
                    style: context.type.tourHeading,
                  ),
                  const SizedBox(height: 16),
                  _Demo(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        for (final (i, point) in _recap.indexed) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: context.pal.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  point,
                                  style: context.type.rowTitleLg,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Demo(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your account when you have time',
                          style: context.type.rowTitleLg,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'It makes your reports count for more. You never '
                          'need it to report.',
                          style: context.type.bodySm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: AppButton('Open the map', large: true, onPressed: onDone),
          ),
        ],
      ),
    );
  }
}
