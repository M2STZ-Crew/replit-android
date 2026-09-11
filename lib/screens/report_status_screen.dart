import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'live_update_screen.dart';

/// "09 Submitting" from the REPLIT-OVERHAUL Figma — "Getting you help".
///
/// The frame is drawn mid-upload ("Sending your report", 50%, "Stay on this
/// screen"). Here the upload has already finished when the screen opens — the
/// report screen waited for the server's answer — so the four steps say what
/// the server has actually done, and the one still open is the coordinator's
/// confirmation, which this screen watches:
///
///   1. received — the photo and fix are stored (the 201 itself);
///   2. matched — clustered into an area, joined or first (GET /areas/{id});
///   3. notified — the area is on the Barangay 76 console, and the server
///      alerted neighbours within 300 m in the same request;
///   4. confirmed — the area leaves `pending`.
class ReportStatusScreen extends StatefulWidget {
  const ReportStatusScreen({
    super.key,
    required this.designation,
    required this.lat,
    required this.lng,
    required this.submittedAt,
    this.message,
    this.areaId,
    this.selectedAgencies = const [],
    this.api,
  });

  final String designation;
  final double lat;
  final double lng;
  final DateTime submittedAt;
  final String? message;
  final String? areaId;
  final List<String> selectedAgencies;
  final ApiClient? api;

  @override
  State<ReportStatusScreen> createState() => _ReportStatusScreenState();
}

enum _Step { done, now }

class _ReportStatusScreenState extends State<ReportStatusScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  Timer? _poll;

  /// The area as last read; null until it answers (or with no area id).
  Map<String, dynamic>? _area;

  @override
  void initState() {
    super.initState();
    if (widget.areaId != null) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final area = await _api.getArea(widget.areaId!);
      if (!mounted) return;
      setState(() => _area = area);
      // Confirmed or closed: nothing more for this screen to wait on.
      if (_status != 'pending') _poll?.cancel();
    } catch (_) {
      // Keep the last reading; the next tick tries again.
    }
  }

  String? get _status => _area?['status'] as String?;

  int? get _reports => (_area?['report_count'] as num?)?.toInt();

  bool get _confirmed =>
      _status != null && _status != 'pending' && _status != 'rejected';

  bool get _refused => _status == 'rejected';

  void _follow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveUpdateScreen(
          areaId: widget.areaId!,
          lat: widget.lat,
          lng: widget.lng,
          alreadySelected: widget.selectedAgencies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final designation =
        (_area?['designation'] as String?) ?? widget.designation;
    final reports = _reports;
    final matchLine = reports == null
        ? 'Grouped with reports within 300 m'
        : reports > 1
        ? 'Within 300 m of an active area'
        : 'A new area — the first report here';

    final done = _confirmed || _refused ? 4 : 3;
    final (String phase, double fraction) = _refused
        ? ('Closed', 1.0)
        : _confirmed
        ? ('Confirmed', 1.0)
        : ('Confirming', 0.75);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          content: [
            Eyebrow(
              _refused ? 'Report closed' : 'Report sent',
              color: _refused ? AppColors.muted : AppColors.accent,
            ),
            const SizedBox(height: 10),
            const Text(
              'GETTING YOU HELP',
              textAlign: TextAlign.center,
              style: AppText.heading1,
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 290,
                child: Text(
                  _refused
                      ? 'A coordinator could not confirm this one. If it is '
                            'still happening, send another report or call a '
                            'hotline.'
                      : 'You do not need to do anything else. This screen '
                            'follows your report until a coordinator '
                            'confirms it.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Center(child: _ring(fraction, phase)),
            const SizedBox(height: 36),
            _StepRow(
              state: _Step.done,
              title: 'Report received',
              line: 'Photo and GPS stored',
            ),
            const SizedBox(height: 8),
            _StepRow(
              state: _Step.done,
              title: reports == 1
                  ? '$designation opened'
                  : 'Matched to $designation',
              line: matchLine,
            ),
            const SizedBox(height: 8),
            const _StepRow(
              state: _Step.done,
              title: 'Barangay 76 notified',
              line: 'Neighbours within 300 m were alerted too',
            ),
            const SizedBox(height: 8),
            _StepRow(
              state: done == 4 ? _Step.done : _Step.now,
              title: _refused
                  ? 'Not confirmed'
                  : _confirmed
                  ? 'Confirmed'
                  : 'Coordinator confirms it',
              line: _refused
                  ? 'Closed by a coordinator'
                  : _confirmed
                  ? 'Responders are being assigned'
                  : widget.areaId == null
                  ? 'Open it from Your reports to follow it'
                  : 'Now',
              refused: _refused,
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.areaId != null && !_refused) ...[
                AppButton('Track it live', height: 54, onPressed: _follow),
                const SizedBox(height: 18),
              ],
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ENCRYPTED, SHARED ONLY WITH RESPONDERS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The 144px ring: the share of the four steps behind it, and which step
  /// is open.
  Widget _ring(double fraction, String phase) {
    return Semantics(
      label: '${(fraction * 100).round()} percent. $phase.',
      excludeSemantics: true,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 144,
              height: 144,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.lineStrong,
                color: _refused ? AppColors.muted : AppColors.accent,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(fraction * 100).round()}%', style: AppText.numeralXl),
                const SizedBox(height: 4),
                Text(
                  phase.toUpperCase(),
                  style: AppText.tag.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the four steps: a marker (a tick, or coral while it is the open
/// one), the step, and what it amounts to.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.state,
    required this.title,
    required this.line,
    this.refused = false,
  });

  final _Step state;
  final String title;
  final String line;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final now = state == _Step.now;
    final Widget marker = switch (state) {
      _Step.done => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: (refused ? AppColors.muted : AppColors.ok).withValues(
            alpha: 0.14,
          ),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Icon(
          refused ? Icons.close_rounded : Icons.check_rounded,
          size: 12,
          color: refused ? AppColors.muted : AppColors.ok,
        ),
      ),
      _Step.now => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: now
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          marker,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppText.rowValue.copyWith(
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: AppText.caption.copyWith(
                    color: now ? AppColors.accent : AppColors.muted,
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
