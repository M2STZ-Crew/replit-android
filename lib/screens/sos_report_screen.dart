import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/report_queue.dart';
import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../sound/sound_cues.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'camera_capture_screen.dart';
import 'report_status_screen.dart';

/// One choice in "Who should respond": the agency the server knows, the word
/// a resident knows, and the frame's colour and glyph for it.
typedef _Agency = ({String key, String label, Color color, String glyph});

const List<_Agency> _agencies = [
  (
    key: 'fire_volunteer',
    label: 'Fire',
    color: AppColors.fire,
    glyph: Art.agFire,
  ),
  (
    key: 'medical',
    label: 'Medical',
    color: AppColors.medical,
    glyph: Art.agMedical,
  ),
  (
    key: 'police',
    label: 'Police',
    color: AppColors.police,
    glyph: Art.agPolice,
  ),
  (
    key: 'barangay',
    label: 'Barangay',
    color: AppColors.barangay,
    glyph: Art.agBarangay,
  ),
];

/// "08 Report" from the REPLIT-OVERHAUL Figma — "What are we sending?".
///
/// The frame opens this screen straight from the SOS hold with an empty
/// viewfinder ("Tap to capture"). The app keeps camera-first — the hold
/// opens the camera, the photo is the one thing the server insists on, and
/// the GPS fix finishes while it is taken (v10 §6) — so this screen arrives
/// with the photo already in the viewfinder, and tapping it retakes.
///
/// Agencies are multi-select, not the frame's single choice: /reports/submit
/// takes a list, and a resident who needs an ambulance and a fire truck should
/// be able to say so. The frame's "Location already sent" is not claimed —
/// nothing is sent until "Send report" — so the chip says whether the fix is
/// in hand.
///
/// The location is [SosLocation]'s fix, which may still be arriving when this
/// screen opens. "Send report" waits for it only if it has not. With no answer
/// from the server at all, the report is saved on the phone ([ReportQueue]).
class SosReportScreen extends StatefulWidget {
  const SosReportScreen({
    super.key,
    required this.photoBytes,
    this.address,
    this.api,
  });

  final List<int> photoBytes;
  final String? address;
  final ApiClient? api;

  @override
  State<SosReportScreen> createState() => _SosReportScreenState();
}

class _SosReportScreenState extends State<SosReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final SosLocation _location = SosLocation.instance;
  final TextEditingController _notes = TextEditingController();
  final Map<String, bool> _selected = {
    'fire_volunteer': true,
    'medical': false,
    'police': false,
    'barangay': false,
  };

  late List<int> _photo = widget.photoBytes;
  late String? _address = widget.address;

  bool _submitting = false;

  /// True while a pressed "Send" is still waiting on the GPS fix.
  bool _waitingForFix = false;

  Position? get _position => _location.position.value;

  @override
  void initState() {
    super.initState();
    _location.position.addListener(_rebuild);
  }

  @override
  void dispose() {
    _location.position.removeListener(_rebuild);
    _notes.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  Future<void> _retake() async {
    final shot = await Navigator.of(context).push<RetakenPhoto>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(retake: true),
      ),
    );
    if (shot == null || !mounted) return;
    setState(() {
      _photo = shot.bytes;
      _address = shot.address ?? _address;
    });
  }

  Future<void> _requestHelp() async {
    final agencies = _selected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (agencies.isEmpty) {
      _toast('Choose at least one kind of help.');
      return;
    }

    final timing = ReportTiming.instance;
    timing.mark('send_pressed');
    setState(() {
      _submitting = true;
      _waitingForFix = _position == null;
    });
    Position? pos;
    try {
      // Usually already here: it has been working since the SOS hold began.
      pos = await _location.forReport();
      if (!mounted) return;
      setState(() => _waitingForFix = false);
      if (pos == null) {
        timing.finish(outcome: 'no_location');
        _toast(
          _location.problem.value ??
              'Could not pinpoint your location. Move near a window or outdoors and try again.',
        );
        return;
      }
      timing.mark('upload_started');
      final data = await _api.submitReport(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        agencies: agencies,
        notes: _notes.text.trim(),
        photoBytes: _photo,
      );
      timing.mark('server_ack');
      timing.finish(outcome: 'sent');
      if (!mounted) return;
      // "Salamat!" (v10 §2.8) — not awaited, so the sound never holds up the
      // status screen.
      SoundCues.instance.playReportSent();
      await _showSuccess(data, agencies, pos);
    } on ApiException catch (e) {
      timing.finish(outcome: 'rejected');
      _toast(e.message);
    } catch (_) {
      // No answer at all — no signal, most likely. With a fix in hand the
      // report is not lost: it is saved on the phone and sends itself when
      // the signal returns ("05 Map — offline queue"). The map shows it.
      final at = pos;
      if (at == null) {
        timing.finish(outcome: 'failed');
        _toast('Could not submit the report. Check your connection.');
      } else {
        await _saveForLater(at, agencies);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _waitingForFix = false;
        });
      }
    }
  }

  Future<void> _saveForLater(Position pos, List<String> agencies) async {
    final timing = ReportTiming.instance;
    try {
      await ReportQueue.instance.enqueue(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        agencies: agencies,
        notes: _notes.text.trim(),
        photoBytes: _photo,
      );
    } catch (_) {
      timing.finish(outcome: 'failed');
      _toast('Could not submit the report or save it. Check your connection.');
      return;
    }
    timing.finish(outcome: 'queued');
    if (!mounted) return;
    AppNavBar.switchTo(context, AppTab.map);
  }

  Future<void> _showSuccess(
    Map<String, dynamic> data,
    List<String> agencies,
    Position pos,
  ) async {
    final createdRaw = data['created_at'] as String?;
    DateTime when;
    try {
      when = createdRaw != null
          ? DateTime.parse(createdRaw).toLocal()
          : DateTime.now();
    } catch (_) {
      when = DateTime.now();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportStatusScreen(
          designation: (data['area_designation'] as String?) ?? '—',
          message: data['message'] as String?,
          areaId: data['area_id'] as String?,
          lat: pos.latitude,
          lng: pos.longitude,
          submittedAt: when,
          selectedAgencies: agencies,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final chosen = _selected.values.where((v) => v).length;
    return Scaffold(
      // The report frame sits on the canvas, not the ground: the viewfinder
      // is a camera surface and the screen darkens around it.
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            Row(
              children: [
                BackWell(
                  onTap: _submitting
                      ? () {}
                      : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 16),
                Flexible(child: _locationChip()),
              ],
            ),
            const SizedBox(height: 28),
            const Text('WHAT ARE WE SENDING?', style: AppText.heading1),
            const SizedBox(height: 32),
            const Eyebrow('Who should respond', color: AppColors.muted),
            const SizedBox(height: 10),
            _agencyGrid(),
            const SizedBox(height: 28),
            const Row(
              children: [
                Expanded(
                  child: Eyebrow('Photo of the scene', color: AppColors.muted),
                ),
                Eyebrow('Required', color: AppColors.accent),
              ],
            ),
            const SizedBox(height: 10),
            _viewfinder(),
            const SizedBox(height: 24),
            const Eyebrow('Anything else', color: AppColors.muted),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              style: AppText.bodySm.copyWith(color: AppColors.onBackground),
              decoration: InputDecoration(
                hintText: 'Optional — what responders should know',
                hintStyle: AppText.bodySm.copyWith(
                  color: AppColors.label.withValues(alpha: 0.45),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_waitingForFix) ...[
                Text(
                  'Pinpointing your location — your report sends the moment '
                  'it is found.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.accent),
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                chosen == 0 ? 'Choose who to call' : 'Send report',
                height: 54,
                busy: _submitting,
                onPressed: _submitting || chosen == 0 ? null : _requestHelp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether the fix is in hand. (The frame's "Location already sent" would
  /// be untrue: the location goes with the report, on "Send report".)
  Widget _locationChip() {
    final fixed = _position != null;
    final tone = fixed ? AppColors.ok : AppColors.warn;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fixed)
            const Icon(Icons.check_rounded, size: 12, color: AppColors.ok)
          else
            const LiveDot(color: AppColors.warn, size: 6),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              fixed ? 'LOCATION LOCKED' : 'FINDING YOUR LOCATION',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tag.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agencyGrid() {
    Widget row(_Agency a, _Agency b) => Row(
      children: [
        Expanded(child: _agencyCard(a)),
        const SizedBox(width: 8),
        Expanded(child: _agencyCard(b)),
      ],
    );
    return Column(
      children: [
        row(_agencies[0], _agencies[1]),
        const SizedBox(height: 8),
        row(_agencies[2], _agencies[3]),
      ],
    );
  }

  Widget _agencyCard(_Agency a) {
    final on = _selected[a.key] ?? false;
    final shape = BorderRadius.circular(AppRadius.card);
    return Semantics(
      button: true,
      checked: on,
      label: a.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: _submitting
              ? null
              : () => setState(() => _selected[a.key] = !on),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on ? a.color.withValues(alpha: 0.16) : AppColors.glass,
              borderRadius: shape,
              border: Border.all(
                color: on ? a.color : AppColors.line,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(a.glyph, width: 19, height: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      a.label.toUpperCase(),
                      style: AppText.cardTitleSm.copyWith(
                        color: on ? AppColors.onBackground : AppColors.textSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: on ? a.color : AppColors.muted,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: on
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: a.color,
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

  /// The photo in the frame's viewfinder: coral brackets, the geotag, and a
  /// tap to take it again.
  Widget _viewfinder() {
    final pos = _position;
    final tag = pos == null
        ? 'Pinpointing your location…'
        : 'Geotagged, ${_address ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'}';
    return Semantics(
      button: true,
      label: 'Photo of the scene. Tap to take it again.',
      child: GestureDetector(
        onTap: _submitting ? null : _retake,
        child: Container(
          height: 214,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(Uint8List.fromList(_photo), fit: BoxFit.cover),
              // Keeps the chips legible over a bright photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000B0B0B), Color(0xB30B0B0B)],
                    stops: [0.5, 1],
                  ),
                ),
              ),
              const CustomPaint(painter: _BracketPainter()),
              Positioned(
                left: 17,
                right: 17,
                bottom: 19,
                child: Row(
                  children: [
                    Flexible(
                      child: _FrameChip(
                        leading: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.live,
                            shape: BoxShape.circle,
                          ),
                        ),
                        text: tag,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _FrameChip(
                      leading: Icon(
                        Icons.photo_camera_outlined,
                        size: 12,
                        color: AppColors.onBackground,
                      ),
                      text: 'Retake',
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

/// A dark chip laid over the viewfinder photo.
class _FrameChip extends StatelessWidget {
  const _FrameChip({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD10B0B0B),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tag.copyWith(color: AppColors.onBackground),
            ),
          ),
        ],
      ),
    );
  }
}

/// The viewfinder's four coral corner brackets: 32px arms, 8px corner
/// radius, 15px in from each edge.
class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 15.0;
    const arm = 32.0;
    const r = 8.0;
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // [sx], [sy] point inward from the corner at [o].
    void corner(Offset o, double sx, double sy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * arm)
        ..lineTo(o.dx, o.dy + sy * r)
        ..arcToPoint(
          Offset(o.dx + sx * r, o.dy),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(o.dx + sx * arm, o.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(inset, inset), 1, 1);
    corner(Offset(size.width - inset, inset), -1, 1);
    corner(Offset(inset, size.height - inset), 1, -1);
    corner(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}
