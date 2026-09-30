import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart';
import 'post_incident_report_screen.dart';

/// The "pending report" tray (Master Context v10 §10.2): incidents whose fire
/// is out and for which this captain's team has not filed its Post-Incident
/// Report. Each responding team files its own, so an incident another team has
/// already closed stays here until this team files too. Pops `true` if
/// anything was filed, so the dashboard refreshes its count.
class PendingReportsScreen extends StatefulWidget {
  const PendingReportsScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<PendingReportsScreen> createState() => _PendingReportsScreenState();
}

class _PendingReportsScreenState extends State<PendingReportsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _filedAny = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List<dynamic> raw;
      try {
        raw = await _api.getOwedPostIncidentReports();
      } on ApiException catch (e) {
        // A server from before each team filed its own has no such list: fall
        // back to every incident still waiting on its first report.
        if (e.statusCode != 404 && e.statusCode != 405) rethrow;
        raw = await _api.getIncidents(
          activeOnly: false,
          status: 'post_incident_report',
        );
      }
      if (!mounted) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load pending reports. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> inc) async {
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostIncidentReportScreen(
          areaId: inc['id'] as String,
          designation: inc['designation'] as String?,
          api: _api,
        ),
      ),
    );
    if (filed == true) {
      _filedAny = true;
      _load();
    }
  }

  static String _ago(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return '';
    final mins = DateTime.now().difference(t).inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '$mins min ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ${mins % 60}m ago';
    return '${hrs ~/ 24}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_filedAny);
      },
      child: StaffScaffold(
        page: StaffPage.reports,
        home: true,
        title: 'Pending reports',
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Fire out, and your team has not filed yet. Each team '
                      'that responded files its own report, for everyone on '
                      'it who went.',
                      style: context.type.body.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconWellButton(
                    icon: Icons.refresh_rounded,
                    size: 40,
                    onTap: _load,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: context.pal.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: context.pal.muted)),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded, color: context.pal.ok, size: 40),
            const SizedBox(height: 12),
            Text(
              'Nothing owed. Every report is filed.',
              style: context.type.meta,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: context.pal.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final inc = _items[i];
          final tint = context.pal.forStatus('post_incident_report');
          return Panel(
            onTap: () => _open(inc),
            color: context.pal.glassDim,
            border: tint.withValues(alpha: 0.35),
            child: Row(
              children: [
                IconWell(tint: tint, icon: Icons.assignment_late_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ((inc['designation'] as String?) ?? 'Incident')
                            .toUpperCase(),
                        style: context.type.cardTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fire out ${_ago(inc['resolved_at'] as String?)}',
                        style: context.type.meta,
                      ),
                    ],
                  ),
                ),
                Tag('File', color: tint),
              ],
            ),
          );
        },
      ),
    );
  }
}
