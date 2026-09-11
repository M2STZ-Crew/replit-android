import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/resident_status.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'live_update_screen.dart';
import 'report_status_screen.dart';

/// What each agency a report asked for is called on its card, and its glyph.
const Map<String, ({String word, String glyph})> _agencies = {
  'fire_volunteer': (word: 'Fire', glyph: Art.agFire),
  'bfp': (word: 'Fire', glyph: Art.agFire),
  'medical': (word: 'Medical', glyph: Art.agMedical),
  'police': (word: 'Police', glyph: Art.agPolice),
  'barangay': (word: 'Barangay', glyph: Art.agBarangay),
};

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime? _createdAt(Map<String, dynamic> r) =>
    DateTime.tryParse('${r['created_at']}')?.toLocal();

/// "17 My reports" from the REPLIT-OVERHAUL Figma — "Your reports".
///
/// Three tiles — sent, active, resolved — then everything sent, by month,
/// each with where it got to. Two things in the frame are not claimed: a
/// report carries no incident type, so its title is what was asked for
/// ("Fire report"); and the footnote that reports "stay on your phone for a
/// year" is not true of this app — they live on the server and are fetched
/// each time — so the footnote says who can see them instead.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

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
      // A refresh keeps the list on screen; only the first load spins.
      _loading = _reports == null;
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
    final when = _createdAt(r) ?? DateTime.now();

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

  /// "This month", else the month's name — with the year once it is not
  /// this one.
  static String _section(DateTime? d) {
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month) return 'This month';
    final month = _months[d.month - 1];
    return d.year == now.year ? month : '$month ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: ScreenHeader(title: 'Your reports'),
            ),
            const SizedBox(height: 26),
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
    if (_error != null && _reports == null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: AppColors.live,
        title: 'Could not load your reports',
        body: _error!,
        action: AppButton.secondary('Try again', onPressed: _load),
      );
    }

    // The server sends newest first; sorting again keeps the month groups
    // honest if it ever does not.
    final reports = [...?_reports]
      ..sort(
        (a, b) => (_createdAt(b) ?? DateTime(0)).compareTo(
          _createdAt(a) ?? DateTime(0),
        ),
      );
    final statuses = [
      for (final r in reports) residentStatus(r['area_status'] as String?),
    ];
    final active = statuses.where((s) => !residentOver(s)).length;
    final resolved = statuses.where((s) => s == 'resolved').length;

    final sections = <String, List<Map<String, dynamic>>>{};
    for (final r in reports) {
      sections.putIfAbsent(_section(_createdAt(r)), () => []).add(r);
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  value: '$active',
                  label: 'Active',
                  color: active > 0 ? AppColors.live : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  value: '$resolved',
                  label: 'Resolved',
                  color: AppColors.ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (reports.isEmpty)
            const EmptyState(
              title: 'Nothing sent yet',
              body:
                  'Reports you send appear here with what came of them — '
                  'who was sent, and when it was resolved.',
            )
          else
            for (final MapEntry(key: label, value: group)
                in sections.entries) ...[
              Eyebrow(
                label,
                color: label == 'This month'
                    ? AppColors.accent
                    : AppColors.label,
              ),
              const SizedBox(height: 12),
              for (final r in group) ...[
                _ReportCard(report: r, onTap: () => _openReport(r)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Other residents never see your name or your photos — '
                  'only the responders and barangay staff handling the '
                  'incident do.',
                  style: AppText.caption.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One sent report: what was asked for, where and when, where it got to.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  /// "Today at 9:41 AM", else "14 August".
  static String _when(DateTime? d) {
    if (d == null) return 'Date unknown';
    final now = DateTime.now();
    if (d.year != now.year || d.month != now.month || d.day != now.day) {
      return '${d.day} ${_months[d.month - 1]}';
    }
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Today at $h:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final status = residentStatus(report['area_status'] as String?);
    final over = residentOver(status);
    final tone = residentTone(status);
    final asked = [
      for (final a in (report['selected_agencies'] as List? ?? const []))
        ?_agencies['$a'],
    ];
    final words = {for (final a in asked) a.word};
    final title = words.isEmpty ? 'Report' : '${words.join(' + ')} report';
    final designation = report['area_designation'] as String?;
    final band = report['area_confidence_band'] as String?;
    final flagged = report['gps_discrepancy_flag'] == true;

    final footer = switch (status) {
      'resolved' => [?designation, 'resolved'].join(' · '),
      'rejected' => 'Closed — it could not be confirmed',
      'merged' => 'Joined to a neighbouring incident',
      _ when designation == null => 'Waiting to be grouped with others',
      _ => [designation, if (band != null) '$band confidence'].join(' · '),
    };

    return Semantics(
      button: true,
      label: '$title, ${residentWord(status)}',
      child: Panel(
        onTap: onTap,
        radius: AppRadius.panel,
        border: over ? null : tone.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconWell(
                  tint: tone,
                  asset: asked.isEmpty ? Art.incident : asked.first.glyph,
                  size: 34,
                  glyph: 17,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _when(_createdAt(report)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tag(residentWord(status), color: tone, dot: !over),
              ],
            ),
            const SizedBox(height: 13),
            Divider(
              height: 1,
              thickness: 1,
              color: over ? AppColors.line : tone.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    footer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: over ? AppColors.muted : AppColors.label,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  over ? 'DETAILS' : 'TRACK',
                  style: AppText.eyebrow.copyWith(
                    color: over ? AppColors.label : AppColors.accent,
                  ),
                ),
              ],
            ),
            if (flagged) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.warn,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Being double-checked — the photo and your phone '
                      'disagreed on where it was taken.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
