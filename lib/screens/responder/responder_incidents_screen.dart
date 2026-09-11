import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/placeholder_box.dart';
import 'responder_incident_report_screen.dart';
import 'responder_incident_screen.dart';
import 'responder_status.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _grey = AppColors.muted;
const Color _green = AppColors.ok;
const Color _orange = AppColors.accent;
const Color _red = AppColors.live;
const Color _label = AppColors.label;

/// Area-header colour by incident status (matches the sub-admin feed).
Color _areaColor(String s) {
  switch (s) {
    case 'verified':
    case 'resolved':
    case 'post_incident_report':
    case 'closed':
      return _green;
    case 'dispatched':
    case 'en_route':
    case 'arrived':
      return _orange;
    case 'rejected':
      return _red;
    default:
      return _grey; // pending
  }
}

/// Responder-centric status pill for a report card.
(String, Color) _responderPill(String s) {
  switch (s) {
    case 'verified':
      return ('RESPOND', _green);
    case 'dispatched':
    case 'en_route':
      return ('RESPONDING', _orange);
    case 'arrived':
      return ('ACTIVE', _red);
    case 'resolved':
    case 'post_incident_report':
    case 'closed':
      return ('RESOLVED', _green);
    case 'rejected':
      return ('REJECTED', _red);
    default:
      return ('PENDING', _grey);
  }
}

/// Responder incident feed — incident AREAS as expandable section headers; each
/// expands to its citizen reports. OPEN on a live incident's header goes to the
/// responder incident screen (respond / en-route / arrived); tapping a report
/// shows what the citizen reported. The pill shows the responder action / state
/// for that incident, and a green tag says when Admin has routed it to the
/// responder's agency (v10 §2.6.2).
class ResponderIncidentsScreen extends StatefulWidget {
  const ResponderIncidentsScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  @override
  State<ResponderIncidentsScreen> createState() => _ResponderIncidentsScreenState();
}

class _ResponderIncidentsScreenState extends State<ResponderIncidentsScreen> {
  final ApiClient _api = ApiClient();
  Timer? _poll;

  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;
  String? _error;

  final Set<String> _expanded = {};
  final Map<String, List<Map<String, dynamic>>> _reports = {};
  final Set<String> _reportsLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final raw = await _api.getIncidents();
      if (!mounted) return;
      setState(() {
        _areas = raw.cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
      for (final id in _expanded) {
        _loadReports(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load incidents. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadReports(String areaId) async {
    if (_reportsLoading.contains(areaId)) return;
    _reportsLoading.add(areaId);
    try {
      final raw = await _api.getIncidentReports(areaId);
      if (mounted) setState(() => _reports[areaId] = raw.cast<Map<String, dynamic>>());
    } catch (_) {
      // leave previous
    } finally {
      _reportsLoading.remove(areaId);
    }
  }

  void _toggle(String areaId) {
    setState(() {
      if (_expanded.contains(areaId)) {
        _expanded.remove(areaId);
      } else {
        _expanded.add(areaId);
        if (!_reports.containsKey(areaId)) _loadReports(areaId);
      }
    });
  }

  Future<void> _openReportDetail(Map<String, dynamic> r, String status, String areaId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentReportScreen(
          report: r,
          areaId: areaId,
          status: status,
          me: widget.me,
          api: _api,
        ),
      ),
    );
    if (mounted) _load(silent: true);
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _panelBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Incidents',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return _centered(Icons.cloud_off, _error!, retry: true);
    }
    if (_areas.isEmpty) {
      return _centered(Icons.inbox_outlined, 'No incidents right now.');
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceSolid,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _areas.length,
        itemBuilder: (_, i) => _areaSection(_areas[i]),
      ),
    );
  }

  String? get _agency => widget.me['agency_type'] as String?;

  /// Open the incident itself — where Respond, En route and Arrived are. The
  /// report cards below only show what a citizen reported.
  Future<void> _openIncident(String areaId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentScreen(
          incidentId: areaId,
          myId: widget.me['id'] as String? ?? '',
          agency: _agency,
          orgId: widget.me['primary_org_id'] as String?,
        ),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Widget _areaSection(Map<String, dynamic> area) {
    final id = area['id'] as String;
    final status = (area['status'] as String?) ?? 'pending';
    final color = _areaColor(status);
    final open = _expanded.contains(id);
    final routed = routingLabel(area, agency: _agency);
    final actionable = const {'verified', 'dispatched', 'en_route', 'arrived'}.contains(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggle(id),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _panelBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ((area['designation'] as String?) ?? 'Area').toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (routed != null) ...[
                        const SizedBox(height: 6),
                        Tag(routed, color: _green, dot: true),
                      ],
                    ],
                  ),
                ),
                if (actionable)
                  TextButton(
                    onPressed: () => _openIncident(id),
                    child: const Text(
                      'OPEN',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                AnimatedRotation(
                  turns: open ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.keyboard_arrow_down, color: _grey, size: 20),
                ),
              ],
            ),
          ),
        ),
        if (open) _areaReports(id, status),
      ],
    );
  }

  Widget _areaReports(String areaId, String status) {
    final reports = _reports[areaId];
    if (reports == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }
    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Text('No reports in this area.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          for (final r in reports) ...[
            _reportCard(r, status, areaId),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r, String status, String areaId) {
    final (pill, color) = _responderPill(status);
    final name = (r['reporter_name'] as String?)?.toUpperCase() ?? 'UNKNOWN REPORTER';
    final created = r['created_at'] as String?;
    return GestureDetector(
      onTap: () => _openReportDetail(r, status, areaId),
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: _panelBorder),
        ),
        child: Row(
          children: [
            _thumb(r['photo_url'] as String?),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _label,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      height: 1.6,
                    ),
                  ),
                  Text(_fmtDate(created),
                      style: const TextStyle(color: _label, fontSize: 11, letterSpacing: 1)),
                  Text(_fmtTime(created),
                      style: const TextStyle(color: _label, fontSize: 11, letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                pill,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String? url) {
    const double size = 57;
    if (url == null) {
      return const PlaceholderBox(
        width: size,
        height: size,
        label: '',
        icon: Icons.photo_outlined,
        radius: 10,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    width: size,
                    height: size,
                    color: const Color(0x7F303030),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    ),
                  ),
            errorBuilder: (context, error, stack) => const PlaceholderBox(
              width: size,
              height: size,
              label: '',
              icon: Icons.broken_image_outlined,
              radius: 10,
            ),
          ),
          // Subtle scrim (matches the Figma dimmed thumbnail).
          Container(width: size, height: size, color: const Color(0x22000000)),
        ],
      ),
    );
  }

  Widget _centered(IconData icon, String message, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.outline, size: 44),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5)),
            if (retry) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Retry',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
