import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'live_update_screen.dart';
import 'report_status_screen.dart';

const Map<String, String> _agencyLabels = {
  'fire_volunteer': 'Fire Volunteer',
  'bfp': 'BFP',
  'barangay': 'Barangay',
  'medical': 'Medical',
  'police': 'Police',
};

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Terminal statuses — mirrors TERMINAL_STATUSES in app/services/incident.py.
const Set<String> _terminal = {'resolved', 'rejected', 'merged'};

String _statusLabel(String? status) => switch (status) {
  'pending' => 'Awaiting verification',
  'verified' => 'Verified',
  'dispatched' => 'Responders dispatched',
  'en_route' => 'Responders en route',
  'arrived' => 'Responders on scene',
  'resolved' => 'Resolved',
  'rejected' => 'Rejected',
  'merged' => 'Merged',
  _ => 'Received',
};

/// "Your reports" — the incident-history screen from the v2 hand-off.
///
/// The design's three tiles were Sent / Resolved / Avg arrival. The first two
/// are countable from the reports themselves; arrival time is not, because
/// /reports/mine carries no dispatch timestamps. It is replaced with the count
/// still open, which is the number a reporter actually wants: is anyone still
/// coming?
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>>? _reports;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.getMyReports();
      if (mounted) setState(() => _reports = raw.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load your reports. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      final mm = d.minute.toString().padLeft(2, '0');
      return '${_months[d.month - 1]} ${d.day} · $h:$mm $ampm';
    } catch (_) {
      return iso;
    }
  }

  String _agencyText(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return 'No agency selected';
    return raw.map((a) => _agencyLabels[a] ?? a.toString()).join(' · ');
  }

  /// Open a submitted report's incident: resolve its area (nearest centroid)
  /// and show the live tracker; fall back to the status view if no area
  /// matches — e.g. the incident was resolved long ago.
  Future<void> _openReport(Map<String, dynamic> r) async {
    final lat = (r['device_lat'] as num?)?.toDouble();
    final lng = (r['device_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final agencies =
        (r['selected_agencies'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    DateTime when;
    try {
      when = DateTime.parse(r['created_at'] as String).toLocal();
    } catch (_) {
      when = DateTime.now();
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final areaId = r['area_id'] as String? ?? await _findAreaId(lat, lng);
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss the spinner

    if (areaId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveUpdateScreen(
            areaId: areaId,
            lat: lat,
            lng: lng,
            alreadySelected: agencies,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportStatusScreen(
            designation: (r['area_designation'] as String?) ?? '—',
            lat: lat,
            lng: lng,
            submittedAt: when,
            selectedAgencies: agencies,
          ),
        ),
      );
    }
    // Agencies may have changed via "add more help"; refresh on return.
    if (mounted) _load();
  }

  Future<String?> _findAreaId(double lat, double lng) async {
    try {
      final areas = await _api.getAreas(activeOnly: false);
      double? bestM;
      String? bestId;
      for (final a in areas) {
        final m = a as Map<String, dynamic>;
        final clat = (m['centroid_lat'] as num?)?.toDouble();
        final clng = (m['centroid_lng'] as num?)?.toDouble();
        if (clat == null || clng == null) continue;
        final d = _meters(lat, lng, clat, clng);
        if (bestM == null || d < bestM) {
          bestM = d;
          bestId = m['id'] as String?;
        }
      }
      if (bestM != null && bestM <= 800) return bestId;
    } catch (_) {
      // fall through to the status view
    }
    return null;
  }

  double _meters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: ScreenHeader(
                title: 'Your reports',
                trailing: IconWellButton(
                  icon: Icons.refresh_rounded,
                  tint: AppColors.muted,
                  onTap: _loading ? () {} : _load,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: AppColors.live,
        title: 'Could not load your reports',
        body: _error!,
        action: AppButton.secondary('Try again', onPressed: _load),
      );
    }

    final reports = _reports ?? [];
    final resolved = reports.where((r) => r['area_status'] == 'resolved').length;
    final open = reports
        .where((r) => !_terminal.contains(r['area_status'] as String?))
        .length;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceSolid,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(value: '${reports.length}', label: 'Sent'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  value: '$resolved',
                  label: 'Resolved',
                  color: AppColors.ok,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  value: '$open',
                  label: 'Still open',
                  color: open > 0 ? AppColors.accent : AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (reports.isEmpty)
            const EmptyState(
              title: 'Nothing sent yet',
              body: 'Reports you send appear here with what came of them — who '
                  'responded, and when it was closed.',
            )
          else ...[
            const Eyebrow('Everything you have sent', color: AppColors.accent),
            const SizedBox(height: 12),
            for (final r in reports) ...[
              _reportCard(r),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final photoUrl = r['photo_url'] as String?;
    final flagged = r['gps_discrepancy_flag'] == true;
    final status = r['area_status'] as String?;
    final live = !_terminal.contains(status);
    final color = AppColors.forStatus(status);
    final designation = (r['area_designation'] as String?) ?? 'Awaiting grouping';

    return Panel(
      onTap: () => _openReport(r),
      color: live ? color.withValues(alpha: 0.08) : AppColors.glassDim,
      border: live ? color.withValues(alpha: 0.35) : AppColors.line,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      designation.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fmtDate(r['created_at'] as String?),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta,
                    ),
                    const SizedBox(height: 10),
                    Tag(
                      _statusLabel(status),
                      color: color,
                      dot: live && status != null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.faint,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: color.withValues(alpha: live ? 0.2 : 0.12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _agencyText(r['selected_agencies'] as List<dynamic>?),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(
                    color: live ? AppColors.label : AppColors.muted,
                  ),
                ),
              ),
              if (r['area_confidence_band'] != null) ...[
                const SizedBox(width: 10),
                Text(
                  '${(r['area_confidence_band'] as String).toUpperCase()} CONFIDENCE',
                  style: AppText.tag.copyWith(
                    color: switch (r['area_confidence_band']) {
                      'high' => AppColors.ok,
                      'medium' => AppColors.warn,
                      _ => AppColors.muted,
                    },
                  ),
                ),
              ],
            ],
          ),
          if (flagged) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.warn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Being double-checked — the photo and your phone disagreed '
                    'on the location.',
                    style: AppText.meta.copyWith(height: 15 / 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumbnail(String? url) {
    const double size = 66;
    Widget fallback(IconData icon) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.line),
      ),
      child: Icon(icon, color: AppColors.faint, size: 22),
    );

    if (url == null) return fallback(Icons.photo_outlined);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppColors.canvas,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        // Signed URLs expire; a broken image must not read as a lost report.
        errorBuilder: (context, error, stack) =>
            fallback(Icons.broken_image_outlined),
      ),
    );
  }
}
