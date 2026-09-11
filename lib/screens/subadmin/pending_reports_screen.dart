import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import 'post_incident_report_screen.dart';

/// The "pending report" tray (Master Context v10 §10.2): incidents whose fire
/// is out but whose Post-Incident Report has not been filed. They stay here —
/// and cannot close — until the team captain files. Pops `true` if anything was
/// filed, so the dashboard refreshes its count.
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
      final raw = await _api.getIncidents(activeOnly: false, status: 'post_incident_report');
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  eyebrow: 'Post-Incident Reports',
                  title: 'Pending reports',
                  trailing: IconWellButton(icon: Icons.refresh_rounded, onTap: _load),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fire out, report not yet filed. Each one stays open until its '
                  'team captain files — for everyone who went.',
                  style: AppText.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 18),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.muted)));
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded, color: AppColors.ok, size: 40),
            const SizedBox(height: 12),
            Text('Nothing owed. Every report is filed.', style: AppText.meta),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final inc = _items[i];
          final tint = AppColors.forStatus('post_incident_report');
          return Panel(
            onTap: () => _open(inc),
            color: AppColors.glassDim,
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
                        ((inc['designation'] as String?) ?? 'Incident').toUpperCase(),
                        style: AppText.cardTitle,
                      ),
                      const SizedBox(height: 6),
                      Text('Fire out ${_ago(inc['resolved_at'] as String?)}', style: AppText.meta),
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
