import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../providers/sos_provider.dart';

/// The SOS flow from the hand-off: hold, say what is happening, show them, send.
///
/// Two things the design promises are not built, because the backend cannot
/// honour them and a button that lies in an emergency is worse than no button:
///
///   * "Skip the photo" — POST /reports/submit rejects a report without one.
///     The photo is what the server cross-references against your GPS fix, so
///     it is load-bearing, not decorative.
///   * The voice-note recorder — no endpoint accepts audio.
///
/// The design also says the alert leaves on the hold and the rest is detail.
/// There is one submission endpoint, so the hold gets your location and the
/// report goes when it is complete. The copy says that plainly rather than
/// implying help is already moving.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, this.onProfile});

  final VoidCallback? onProfile;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

/// What kind of emergency, in the words a resident would use — and the
/// agencies each answer dispatches.
enum EmergencyKind {
  fire('Fire', 'Smoke, flames, burning smell', {
    AgencyType.fireVolunteer,
    AgencyType.bfp,
  }),
  medical('Medical', 'Injury, collapse, trouble breathing', {
    AgencyType.medical,
  }),
  crime('Crime', 'Happening now, someone at risk', {AgencyType.police}),
  other('Something else', 'Flooding, a hazard, anything else', {
    AgencyType.barangay,
  });

  const EmergencyKind(this.label, this.blurb, this.agencies);

  final String label;
  final String blurb;
  final Set<String> agencies;

  Color get tint => switch (this) {
    EmergencyKind.fire => AppColors.live,
    EmergencyKind.medical => AppColors.ok,
    EmergencyKind.crime => AppColors.crime,
    EmergencyKind.other => AppColors.label,
  };

  String? get art => switch (this) {
    EmergencyKind.fire => Art.agencyBfp,
    EmergencyKind.crime => Art.agencyPnp,
    _ => null,
  };
}

enum _Step { hold, select, capture }

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: AppConstants.sosHoldDuration,
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      ref.read(sosProvider.notifier).acquireLocation();
    }
  });

  _Step _step = _Step.hold;
  EmergencyKind? _kind;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _hold.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _startHold() {
    if (ref.read(sosProvider).isBusy) return;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _cancelHold() {
    if (!_hold.isCompleted) _hold.reverse();
  }

  void _restart() {
    ref.read(sosProvider.notifier).reset();
    _notes.clear();
    setState(() {
      _step = _Step.hold;
      _kind = null;
    });
    _hold.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sosProvider);

    ref.listen<SosState>(sosProvider, (previous, next) {
      // The fix landing is what advances the flow — the hold's job is done.
      if (previous?.stage != SosStage.ready && next.stage == SosStage.ready) {
        if (_step == _Step.hold) setState(() => _step = _Step.select);
      }
      if (next.stage == SosStage.idle) _hold.value = 0;
    });

    final body = switch (state.stage) {
      SosStage.submitting => _ProcessingView(state: state),
      SosStage.submitted => _SentView(state: state, onDone: _restart),
      _ => switch (_step) {
        _Step.hold => _HoldView(
          controller: _hold,
          state: state,
          onHoldStart: _startHold,
          onHoldEnd: _cancelHold,
          onProfile: widget.onProfile,
        ),
        _Step.select => _SelectView(
          selected: _kind,
          notes: _notes,
          onPick: (kind) {
            HapticFeedback.selectionClick();
            setState(() => _kind = kind);
            ref.read(sosProvider.notifier).setAgencies(kind.agencies);
          },
          onBack: () => setState(() => _step = _Step.hold),
          onNext: _kind == null
              ? null
              : () {
                  ref.read(sosProvider.notifier).setNotes(_notes.text);
                  setState(() => _step = _Step.capture);
                },
        ),
        _Step.capture => _CaptureView(
          state: state,
          kind: _kind!,
          onBack: () => setState(() => _step = _Step.select),
        ),
      },
    };

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          if (state.errorMessage != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: _ErrorBanner(
                message: state.errorMessage!,
                onDismiss: () => ref.read(sosProvider.notifier).dismissError(),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── hold ──────────

class _HoldView extends StatelessWidget {
  const _HoldView({
    required this.controller,
    required this.state,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.onProfile,
  });

  final AnimationController controller;
  final SosState state;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final locating = state.stage == SosStage.locating;

    return DecoratedBox(
      // The one place besides the splash where glow is allowed.
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.9,
          colors: [Color(0x17FF9066), Color(0x00131313)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset(Art.wordmark, height: 30, fit: BoxFit.contain),
                const Spacer(),
                AvatarWell(onTap: onProfile),
              ],
            ),
            const SizedBox(height: 34),
            Container(
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LiveDot(color: AppColors.ember, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    locating
                        ? 'FINDING YOU'
                        : state.position != null
                            ? 'LOCATION READY'
                            : 'CONNECTED · LOCATION ON',
                    style: AppText.eyebrow.copyWith(color: AppColors.label),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "YOU'RE COVERED",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                height: 28 / 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(
              width: 280,
              child: Text(
                'Hold the button when something is wrong. Your location goes '
                'to the responders for your area.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ),

            const Spacer(),
            _HoldButton(
              controller: controller,
              locating: locating,
              onHoldStart: onHoldStart,
              onHoldEnd: onHoldEnd,
            ),
            const SizedBox(height: 26),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final label = locating
                    ? 'GETTING YOUR LOCATION…'
                    : controller.value == 0
                        ? 'HOLD FOR 3 SECONDS'
                        : controller.isAnimating && controller.value < 1
                            ? 'KEEP HOLDING'
                            : 'RELEASE';
                return Column(
                  children: [
                    Text(
                      label,
                      style: AppText.eyebrow.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 106,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: locating ? 1 : controller.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),

            Panel(
              radius: AppRadius.control,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 20, color: AppColors.live),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Only for real emergencies. Every false alert takes a '
                      'truck away from someone who needs it.',
                      style: AppText.meta.copyWith(
                        fontSize: 12,
                        height: 17 / 12,
                        color: AppColors.textSoft,
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

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.controller,
    required this.locating,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final AnimationController controller;
  final bool locating;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS. Press and hold for three seconds to start a report.',
      child: GestureDetector(
        onTapDown: (_) => onHoldStart(),
        onTapUp: (_) => onHoldEnd(),
        onTapCancel: onHoldEnd,
        child: SizedBox(
          width: 244,
          height: 244,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 236,
                height: 236,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => CircularProgressIndicator(
                    value: locating ? null : controller.value,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.lineStrong,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF262626), AppColors.surfaceSolid],
                  ),
                  border: Border.all(color: AppColors.lineStrong),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(Art.mark, width: 64, height: 64),
                    const SizedBox(height: 10),
                    const Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── select ──────────

class _SelectView extends StatelessWidget {
  const _SelectView({
    required this.selected,
    required this.notes,
    required this.onPick,
    required this.onBack,
    required this.onNext,
  });

  final EmergencyKind? selected;
  final TextEditingController notes;
  final ValueChanged<EmergencyKind> onPick;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            children: [
              _StepHeader(step: 1, title: 'Location captured', onBack: onBack),
              const SizedBox(height: 26),
              const Text("WHAT'S HAPPENING?", style: AppText.display),
              const SizedBox(height: 8),
              const Text(
                'Pick the closest one. We already know where you are.',
                style: AppText.body,
              ),
              const SizedBox(height: 22),
              for (final kind in EmergencyKind.values) ...[
                _KindCard(
                  kind: kind,
                  selected: selected == kind,
                  compact: kind == EmergencyKind.other,
                  onTap: () => onPick(kind),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
              const Eyebrow('Optional note'),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 3,
                maxLength: AppConstants.maxNotesLength,
                style: const TextStyle(fontSize: 13, color: AppColors.text),
                decoration: const InputDecoration(
                  hintText: 'Anything responders should know…',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: AppButton(
            selected == null ? 'Choose what is happening' : 'Continue',
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final EmergencyKind kind;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Panel(
        radius: AppRadius.control,
        onTap: onTap,
        color: selected
            ? AppColors.accent.withValues(alpha: 0.1)
            : AppColors.surfaceDim,
        border: selected ? AppColors.accent : AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.add_rounded,
                size: 16,
                color: selected ? AppColors.accent : AppColors.label),
            const SizedBox(width: 12),
            Text(
              kind.label.toUpperCase(),
              style: AppText.tag.copyWith(
                fontSize: 12,
                letterSpacing: 0.8,
                color: selected ? AppColors.accent : AppColors.textSoft,
              ),
            ),
          ],
        ),
      );
    }

    return Panel(
      onTap: onTap,
      color: selected
          ? kind.tint.withValues(alpha: 0.1)
          : AppColors.surfaceDim,
      border: selected ? kind.tint : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          IconWell(
            tint: kind.tint,
            size: 48,
            glyph: 24,
            asset: kind.art,
            icon: kind.art == null ? Icons.add_rounded : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kind.label.toUpperCase(),
                  style: AppText.cardTitle.copyWith(
                    fontSize: 17,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(kind.blurb, style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? kind.tint : Colors.transparent,
              border: Border.all(
                color: selected ? kind.tint : AppColors.lineStrong,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 13, color: AppColors.bg)
                : null,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────── capture ──────────

class _CaptureView extends ConsumerWidget {
  const _CaptureView({
    required this.state,
    required this.kind,
    required this.onBack,
  });

  final SosState state;
  final EmergencyKind kind;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sosProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            children: [
              _StepHeader(step: 2, title: 'Show them', onBack: onBack),
              const SizedBox(height: 24),

              // Viewfinder frame. Tapping anywhere in it opens the camera —
              // a 354×398 target beats hunting for a small button.
              GestureDetector(
                onTap: state.stage == SosStage.submitting
                    ? null
                    : () => notifier.capturePhoto(fromCamera: true),
                child: AspectRatio(
                  aspectRatio: 354 / 398,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.sheet),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.55),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: state.photo == null
                        ? const _Viewfinder()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(state.photo!, fit: BoxFit.cover),
                              Positioned(
                                left: 16,
                                bottom: 16,
                                child: _GeoTag(state: state),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Panel(
                radius: AppRadius.control,
                color: AppColors.surfaceDim,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A photo is required. The server compares where the '
                        'photo was taken against where your phone says you '
                        'are — that check is what makes a report trusted.',
                        style: AppText.meta.copyWith(height: 16 / 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            children: [
              _ShutterButton(
                onTap: () => notifier.capturePhoto(fromCamera: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    AppButton(
                      state.photo == null ? 'Take the photo first' : 'Send report',
                      height: 46,
                      onPressed: state.canSubmit ? notifier.submit : null,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => notifier.capturePhoto(fromCamera: false),
                      child: SizedBox(
                        height: 24,
                        child: Center(
                          child: Text(
                            state.photo == null
                                ? 'CHOOSE FROM GALLERY'
                                : 'RETAKE OR CHOOSE ANOTHER',
                            style: AppText.eyebrow.copyWith(
                              color: AppColors.muted,
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
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    Widget corner(Alignment alignment) => Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border(
              left: alignment.x < 0
                  ? const BorderSide(color: Color(0xE6FF9066), width: 2)
                  : BorderSide.none,
              right: alignment.x > 0
                  ? const BorderSide(color: Color(0xE6FF9066), width: 2)
                  : BorderSide.none,
              top: alignment.y < 0
                  ? const BorderSide(color: Color(0xE6FF9066), width: 2)
                  : BorderSide.none,
              bottom: alignment.y > 0
                  ? const BorderSide(color: Color(0xE6FF9066), width: 2)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        // Faint grid, matching the design's scanning texture.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1C1C1C),
                  AppColors.bg,
                  AppColors.bg.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ),
        corner(Alignment.topLeft),
        corner(Alignment.topRight),
        corner(Alignment.bottomLeft),
        corner(Alignment.bottomRight),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 34,
                color: AppColors.accent.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 10),
              Text(
                "POINT AT WHAT'S WRONG",
                style: AppText.eyebrow.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.accent.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeoTag extends StatelessWidget {
  const _GeoTag({required this.state});

  final SosState state;

  @override
  Widget build(BuildContext context) {
    final accuracy = state.position?.accuracy;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(size: 6),
          const SizedBox(width: 7),
          Text(
            accuracy == null
                ? 'GEOTAGGED'
                : 'GEOTAGGED · ±${accuracy.round()} M',
            style: AppText.tag.copyWith(
              letterSpacing: 1,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take a photo',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.text.withValues(alpha: 0.9),
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(5),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.text,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── processing ──────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.state});

  final SosState state;

  @override
  Widget build(BuildContext context) {
    final pct = (state.uploadProgress * 100).round();
    // Each line is a real stage of the submission, not a decorative checklist:
    // the fix is held, the upload has a byte-level progress callback, and the
    // last two only complete when the server responds.
    final steps = <(String, String, bool)>[
      ('Location locked', 'Done', true),
      (
        'Sending your photo',
        pct >= 100 ? 'Done' : '$pct%',
        state.uploadProgress > 0,
      ),
      ('Clustering with nearby reports', 'Server', pct >= 100),
      ('Alerting responders', 'Server', false),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4),
          radius: 0.85,
          colors: [Color(0x1AFF9066), Color(0x00131313)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        child: Column(
          children: [
            const Eyebrow('Step 3 of 3', color: AppColors.accent),
            const SizedBox(height: 8),
            const Text(
              'GETTING YOU HELP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                height: 32 / 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(
              width: 290,
              child: Text(
                "Stay on this screen. You don't need to do anything else.",
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: state.uploadProgress > 0
                          ? state.uploadProgress
                          : null,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.lineStrong,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: AppText.numeral.copyWith(
                          fontSize: 34,
                          letterSpacing: -1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Eyebrow('Uploading', color: AppColors.muted),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            for (final (label, meta, done) in steps) ...[
              Panel(
                radius: AppRadius.control,
                color: AppColors.surfaceDim,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.accent
                            : AppColors.surfaceRaised,
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: AppColors.onAccent)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: done ? AppColors.text : AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      meta.toUpperCase(),
                      style: AppText.tag.copyWith(
                        letterSpacing: 1,
                        color: done ? AppColors.accent : AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.faint),
                const SizedBox(width: 8),
                Text(
                  'ENCRYPTED IN TRANSIT · SHARED WITH RESPONDERS',
                  style: AppText.tag.copyWith(color: AppColors.faint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── result ──────────

class _SentView extends StatelessWidget {
  const _SentView({required this.state, required this.onDone});

  final SosState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ok.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.ok.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.check_rounded,
                size: 38, color: AppColors.ok),
          ),
          const SizedBox(height: 24),
          const Text(
            'REPORT SENT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 32 / 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'It joined ${result.areaDesignation}. A Fire Volunteer coordinator '
            'reviews it next, and neighbours within '
            '${AppConstants.areaRadiusMeters} m have been alerted.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 24),
          Panel(
            radius: AppRadius.control,
            color: AppColors.surfaceDim,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                const IconWell(
                  tint: AppColors.accent,
                  asset: Art.incident,
                  size: 34,
                  glyph: 17,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.areaDesignation.toUpperCase(),
                        style: AppText.cardTitle,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Track it under Your reports. You will be notified as '
                        'it moves.',
                        style: AppText.meta.copyWith(height: 15 / 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (result.gpsDiscrepancyFlag) ...[
            const SizedBox(height: 12),
            Panel(
              radius: AppRadius.control,
              color: AppColors.statusPending.withValues(alpha: 0.08),
              border: AppColors.statusPending.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 17, color: AppColors.statusPending),
                  const SizedBox(width: 14),
                  Expanded(
                    // Not the citizen's fault and not a rejection — the report
                    // was accepted, it just gets a closer look.
                    child: Text(
                      "The photo's location differs from your phone's. A "
                      'coordinator will double-check it.',
                      style: AppText.meta.copyWith(
                        height: 16 / 11,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          AppButton('Done', onPressed: onDone),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── bits ──────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.onBack,
  });

  final int step;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackWell(onTap: onBack),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow('Step $step of 3', color: AppColors.accent),
              const SizedBox(height: 6),
              Text(title.toUpperCase(), style: AppText.screenTitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.live.withValues(alpha: 0.1),
      border: AppColors.live.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.live),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppText.meta.copyWith(
                fontSize: 12,
                height: 16 / 12,
                color: AppColors.textSoft,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            iconSize: 18,
            color: AppColors.muted,
            icon: const Icon(Icons.close_rounded),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
