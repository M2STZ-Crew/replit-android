import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/home_screen.dart' show kSosHold;
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../i18n/i18n.dart';

/// The tutorial's practice screens: the real screens' look and words, and
/// none of their working parts. Nothing here reaches the server, the report
/// queue, the GPS, the camera or the microphone, and nothing is saved: each
/// control calls the tutorial's own handler, and the "photo" is a drawing.
///
/// The words are the app's own (t()), in the app's language, so the buttons
/// read as they will in a real report; the tutorial's captions carry its
/// chosen language.

/// A place for the tutorial's spotlight to find a control by.
typedef PracticeKeys = ({
  GlobalKey dial,
  GlobalKey shutter,
  GlobalKey location,
  GlobalKey agency,
  GlobalKey form,
  GlobalKey submit,
  GlobalKey updates,
});

PracticeKeys newPracticeKeys() => (
  dial: GlobalKey(debugLabel: 'practice-dial'),
  shutter: GlobalKey(debugLabel: 'practice-shutter'),
  location: GlobalKey(debugLabel: 'practice-location'),
  agency: GlobalKey(debugLabel: 'practice-agency'),
  form: GlobalKey(debugLabel: 'practice-form'),
  submit: GlobalKey(debugLabel: 'practice-submit'),
  updates: GlobalKey(debugLabel: 'practice-updates'),
);

/// The fictional place every practice report is from.
const String kPracticePlace = 'Practice Street, Barangay 76, Pasay';

// ── 02 · The SOS screen ─────────────────────────────────────────────────────

/// "You're covered", with a dial that fills over the real two seconds
/// ([kSosHold]) and calls [onHeld] once when it is full. Let go early and it
/// empties, as the real one does.
class PracticeSos extends StatefulWidget {
  const PracticeSos({super.key, required this.dialKey, required this.onHeld});

  final GlobalKey dialKey;

  /// Held the whole two seconds; null while holding does nothing.
  final VoidCallback? onHeld;

  @override
  State<PracticeSos> createState() => _PracticeSosState();
}

class _PracticeSosState extends State<PracticeSos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: kSosHold)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            HapticFeedback.heavyImpact();
            widget.onHeld?.call();
          }
        });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onHeld == null) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _up() {
    if (_hold.status != AnimationStatus.completed) _hold.reset();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // A short stage (a small phone, large text, a long caption) keeps the
      // dial and drops the words above it.
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return _screen(context, full: box.maxHeight >= 400 * scale);
    },
  );

  Widget _screen(BuildContext context, {required bool full}) {
    final pal = context.pal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (full) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pal.ok.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: pal.ok.withValues(alpha: 0.4)),
            ),
            child: Text(
              t('Connected, location on').toUpperCase(),
              style: context.type.tag.copyWith(color: pal.ok),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t("YOU'RE COVERED"),
            textAlign: TextAlign.center,
            style: context.type.heading2,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 290,
            child: Text(
              t(
                'Hold the SOS button, take one photo, and responders get '
                'your exact location with it.',
              ),
              textAlign: TextAlign.center,
              style: context.type.body,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
              button: true,
              label: t(
                'SOS. Press and hold for two seconds to start a report.',
              ),
              excludeSemantics: true,
              child: Listener(
                key: widget.dialKey,
                onPointerDown: (_) => _down(),
                onPointerUp: (_) => _up(),
                onPointerCancel: (_) => _up(),
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => PracticeDial(progress: _hold.value),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The SOS dial as the SOS screen draws it: a glow, a track with the elapsed
/// arc, and the coral disc.
class PracticeDial extends StatelessWidget {
  const PracticeDial({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  pal.accent.withValues(alpha: 0.22),
                  pal.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: const Size(220, 220),
            painter: _RingPainter(
              progress: progress,
              track: pal.lineStrong,
              elapsed: pal.accentInk,
            ),
          ),
          Container(
            width: 190,
            height: 190,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('SOS'),
                  style: context.type.display.copyWith(
                    color: AppColors.accentText,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('Hold 2 seconds to send'),
                  style: context.type.label.copyWith(
                    color: AppColors.accentText,
                  ),
                ),
              ],
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
    final centre = size.center(Offset.zero);
    final radius = (size.width - 8) / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(centre, radius, line..color = track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        line
          ..color = elapsed
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.elapsed != elapsed;
}

// ── 02 · The photo ──────────────────────────────────────────────────────────

/// The camera, with a drawing for a viewfinder: no camera is opened.
class PracticeCamera extends StatelessWidget {
  const PracticeCamera({
    super.key,
    required this.shutterKey,
    required this.onShutter,
  });

  final GlobalKey shutterKey;
  final VoidCallback? onShutter;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      child: ColoredBox(
        color: pal.canvas,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PracticeScene(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                children: [
                  Text(
                    t('Take the photo'),
                    style: context.type.label.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: t('Take the photo'),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: shutterKey,
                      onTap: onShutter,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The practice photo: a drawing of a house with smoke at a window, so it is
/// never mistaken for a real scene.
class PracticeScene extends StatelessWidget {
  const PracticeScene({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'A drawing of a house with smoke at a window',
    child: const CustomPaint(painter: _ScenePainter()),
  );
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B3A55), Color(0xFF6B4E5E)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
      Paint()..color = const Color(0xFF3A3F3A),
    );
    final house = Rect.fromLTWH(w * 0.28, h * 0.42, w * 0.44, h * 0.32);
    canvas.drawRect(house, Paint()..color = const Color(0xFFB8A48C));
    canvas.drawPath(
      Path()
        ..moveTo(house.left - w * 0.04, house.top)
        ..lineTo(house.center.dx, h * 0.26)
        ..lineTo(house.right + w * 0.04, house.top)
        ..close(),
      Paint()..color = const Color(0xFF7A3B2E),
    );
    final window = Rect.fromLTWH(
      house.left + house.width * 0.15,
      house.top + house.height * 0.2,
      house.width * 0.28,
      house.height * 0.3,
    );
    canvas.drawRect(window, Paint()..color = const Color(0xFFFF9A3C));
    final smoke = Paint()..color = const Color(0x99808890);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(window.center.dx + i * w * 0.03, window.top - i * h * 0.06),
        w * (0.04 + i * 0.015),
        smoke,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        house.right - house.width * 0.3,
        house.bottom - house.height * 0.45,
        house.width * 0.18,
        house.height * 0.45,
      ),
      Paint()..color = const Color(0xFF5A4636),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}

// ── 03–06 · What are we sending? ────────────────────────────────────────────

/// "What are we sending?" with the practice report in it: the location chip,
/// who should respond (Fire always; [medical] when chosen), the drawn photo,
/// a sample note, and Submit Practice Report in place of Send report.
class PracticeReport extends StatelessWidget {
  const PracticeReport({
    super.key,
    required this.keys,
    required this.medical,
    required this.onMedical,
    required this.onSubmit,
  });

  final PracticeKeys keys;
  final bool medical;
  final VoidCallback? onMedical;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              key: keys.form,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: keys.location,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: pal.ok.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(color: pal.ok.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.check, size: 12, color: pal.ok),
                        const SizedBox(width: 7),
                        Text(
                          t('LOCATION LOCKED'),
                          style: context.type.tag.copyWith(color: pal.ok),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(t('WHAT ARE WE SENDING?'), style: context.type.heading1),
                const SizedBox(height: 14),
                Eyebrow(t('Who should respond'), color: pal.muted),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Agency(
                        label: t('Fire'),
                        glyph: Art.agFire,
                        tint: pal.forAgency('fire_volunteer'),
                        on: true,
                        locked: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Agency(
                        key: keys.agency,
                        label: t('Medical'),
                        glyph: Art.agMedical,
                        tint: pal.forAgency('medical'),
                        on: medical,
                        onTap: onMedical,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Agency(
                        label: t('Police'),
                        glyph: Art.agPolice,
                        tint: pal.forAgency('police'),
                        on: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Agency(
                        label: t('Barangay'),
                        glyph: Art.agBarangay,
                        tint: pal.forAgency('barangay'),
                        on: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Eyebrow(t('Photo of the scene'), color: pal.muted),
                    ),
                    Eyebrow(t('Required'), color: pal.accent),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                    border: Border.all(
                      color: pal.accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const PracticeScene(),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        right: 12,
                        child: Text(
                          t('Geotagged, {place}', {'place': kPracticePlace}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.tag.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Eyebrow(t('Anything else'), color: pal.muted),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: pal.inputBg,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: pal.lineStrong),
                  ),
                  child: Text(
                    'Smoke from the second floor',
                    style: context.type.bodySm.copyWith(
                      color: pal.onBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: keys.submit,
          child: AppButton(
            'Submit Practice Report',
            height: 54,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}

/// One agency card, as the report screen draws it.
class _Agency extends StatelessWidget {
  const _Agency({
    super.key,
    required this.label,
    required this.glyph,
    required this.tint,
    required this.on,
    this.locked = false,
    this.onTap,
  });

  final String label;
  final String glyph;
  final Color tint;
  final bool on;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.card);
    return Semantics(
      button: !locked,
      checked: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on ? tint.withValues(alpha: 0.16) : pal.glass,
              borderRadius: shape,
              border: Border.all(
                color: on ? tint : pal.line,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: pal.wellFor(tint),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(glyph, width: 19, height: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label.toUpperCase(),
                      style: context.type.cardTitleSm.copyWith(
                        color: on ? pal.onBackground : pal.textSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (locked)
                  Icon(AppIcons.lock, size: 16, color: tint)
                else
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? tint : pal.muted,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: on
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tint,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 07 · The updates ────────────────────────────────────────────────────────

/// "Getting you help" for the practice report: Reported, then On the way —
/// the words a resident sees. Only the tutorial's own state; nothing is
/// followed.
class PracticeStatus extends StatelessWidget {
  const PracticeStatus({super.key, required this.updatesKey});

  final GlobalKey updatesKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return _screen(context, full: box.maxHeight >= 240 * scale);
    },
  );

  Widget _screen(BuildContext context, {required bool full}) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (full) ...[
          Eyebrow(t('Report sent'), color: pal.accentInk),
          const SizedBox(height: 10),
          Text(
            t('GETTING YOU HELP'),
            textAlign: TextAlign.center,
            style: context.type.heading1,
          ),
          const SizedBox(height: 20),
        ],
        Column(
          key: updatesKey,
          children: [
            _Stage(
              done: true,
              title: t('Reported'),
              line: t('Report received'),
            ),
            const SizedBox(height: 8),
            _Stage(
              done: false,
              title: t('On the way'),
              line: t('Responders are on the way'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.done, required this.title, required this.line});

  final bool done;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: pal.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: done ? pal.line : pal.accentInk.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? pal.ok.withValues(alpha: 0.14) : pal.accentInk,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: done ? Icon(AppIcons.check, size: 12, color: pal.ok) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.type.rowValue),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: context.type.caption.copyWith(
                    color: done ? pal.muted : pal.accentInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
