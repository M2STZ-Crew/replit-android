import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/placeholder_box.dart';
import '../login_screen.dart';
import '../responder/responder_status.dart';
import 'subadmin_incident_command_screen.dart';
import 'subadmin_incident_report_screen.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _grey = AppColors.muted;
const Color _green = AppColors.ok;
const Color _orange = AppColors.accent;
const Color _red = AppColors.live;
const Color _label = AppColors.label;

Color _areaColor(String s) {
  switch (s) {
    case 'verified':
    case 'resolved':
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

/// Sub-admin console — incident areas (expandable) and the citizen reports inside
/// each, for review and the verify / reject / resolve decisions.
class SubAdminHomeScreen extends StatefulWidget {
  const SubAdminHomeScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  @override
  State<SubAdminHomeScreen> createState() => _SubAdminHomeScreenState();
}

class _SubAdminHomeScreenState extends State<SubAdminHomeScreen> {
  final ApiClient _api = ApiClient();
  Timer? _poll;

  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;
  String? _error;

  final Set<String> _expanded = {};
  final Map<String, List<Map<String, dynamic>>> _reports = {};
  final Set<String> _reportsLoading = {};

  String? get _agency => widget.me['agency_type'] as String?;

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
      // refresh any expanded area's reports
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

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await PushService.instance.unregister();
    await _api.logout();
    await Session.instance.clear();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _panelBorder)),
      ),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          GestureDetector(
            onTap: _accountSheet,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _accountSheet() {
    final name =
        (widget.me['full_name'] as String?) ?? (widget.me['email'] as String?) ?? 'Sub-Admin';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Sub-Admin • ${responderAgencyLabel(_agency)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: _red),
              title: const Text('Log out', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
      return _centered(Icons.inbox_outlined, 'No incidents to review right now.');
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

  Widget _areaSection(Map<String, dynamic> area) {
    final id = area['id'] as String;
    final status = (area['status'] as String?) ?? 'pending';
    final color = _areaColor(status);
    final open = _expanded.contains(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggle(id),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _panelBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Row(
                  children: [
                    Text(
                      responderStatusLabel(status),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: open ? 0 : -0.25,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.keyboard_arrow_down, color: _grey, size: 20),
                    ),
                  ],
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
    final color = _areaColor(status);
    final name = (r['reporter_name'] as String?)?.toUpperCase() ?? 'UNKNOWN REPORTER';
    final created = r['created_at'] as String?;
    return GestureDetector(
      onTap: () => _openReport(r, status, areaId),
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
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                responderStatusLabel(status),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
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
      child: Image.network(
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

  // ------------------------------------------------ report + actions ---
  Future<void> _openReport(Map<String, dynamic> r, String status, String areaId) async {
    // Active (dispatched onwards) → command screen; otherwise the verify screen.
    final active = const {'dispatched', 'en_route', 'arrived'}.contains(status);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => active
            ? SubAdminIncidentCommandScreen(areaId: areaId, me: widget.me, api: _api)
            : SubAdminIncidentReportScreen(
                report: r,
                areaId: areaId,
                status: status,
                agency: _agency,
                me: widget.me,
                api: _api,
              ),
      ),
    );
    if (changed == true && mounted) _load(silent: true);
  }
}
