import 'package:flutter/foundation.dart';

/// Where the seconds go in an SOS report (Master Context v10 §6).
///
/// Meeting 12 said the citizen flow takes about 20 seconds and should be
/// faster, and §6 deliberately sets no target until the flow is measured. This
/// is the measurement: each report logs one line breaking the flow into its
/// steps, e.g.
///
///     [report-timing] origin=sos outcome=sent total=12.4s hold_complete=3.0s
///       camera_ready=3.6s location_fix=5.2s photo_taken=6.9s send_pressed=9.8s
///       upload_started=9.8s server_ack=12.4s
///
/// Every figure is seconds since the resident first touched SOS (or tapped
/// Report on a neighbour alert). `upload_started - send_pressed` is time spent
/// still waiting on GPS; `server_ack - upload_started` is the network and the
/// server. Durations only — no location or content is logged.
///
/// Read them from a device with `adb logcat -s flutter | grep report-timing`.
class ReportTiming {
  ReportTiming._();

  static final ReportTiming instance = ReportTiming._();

  final Stopwatch _clock = Stopwatch();
  final List<(String, Duration)> _marks = [];
  String _origin = 'sos';

  bool get running => _clock.isRunning;

  List<(String, Duration)> get marks => List.unmodifiable(_marks);

  /// Start timing a new report. [origin] is 'sos' (the held button), 'map'
  /// (the map's Send an SOS) or 'neighbour_alert'.
  void start(String origin) {
    _origin = origin;
    _marks.clear();
    _clock
      ..reset()
      ..start();
  }

  /// Record a step, once. Ignored when no report is being timed.
  void mark(String step) {
    if (!_clock.isRunning || _marks.any((m) => m.$1 == step)) return;
    _marks.add((step, _clock.elapsed));
  }

  /// Stop, log the breakdown, and return the line (null if nothing was timed).
  String? finish({required String outcome}) {
    if (!_clock.isRunning) return null;
    _clock.stop();
    String s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final line = StringBuffer('[report-timing] origin=$_origin outcome=$outcome ')
      ..write('total=${s(_clock.elapsed)}');
    for (final (step, at) in _marks) {
      line.write(' $step=${s(at)}');
    }
    final out = line.toString();
    debugPrint(out);
    return out;
  }
}
