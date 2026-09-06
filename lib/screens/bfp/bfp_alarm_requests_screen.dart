import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _muted = AppColors.muted;
const Color _label = AppColors.label;
const Color _green = AppColors.ok;
const Color _amber = AppColors.warn;
const Color _red = AppColors.live;

/// BFP alarm-request review queue: Fire-Volunteer sub-admins/responders raise
/// alarm-escalation requests; a BFP sub-admin executes (applies the alarm level)
/// or rejects them. This is BFP's exclusive authority (master context v8 §6).
class BfpAlarmRequestsScreen extends StatefulWidget {
  const BfpAlarmRequestsScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<BfpAlarmRequestsScreen> createState() => _BfpAlarmRequestsScreenState();
}

class _BfpAlarmRequestsScreenState extends State<BfpAlarmRequestsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  Timer? _poll;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _pendingOnly = true;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final raw = await _api.getAlarmRequests(status: _pendingOnly ? 'pending' : null);
      if (!mounted) return;
      setState(() {
        _requests = raw.cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Could not load alarm requests.';
          _loading = false;
        });
      }
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _levelLabel(String raw) => raw
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  (String, Color) _statusPill(String s) {
    switch (s) {
      case 'approved':
        return ('EXECUTED', _green);
      case 'rejected':
        return ('REJECTED', _red);
      default:
        return ('PENDING', _amber);
    }
  }

  String _fmtWhen(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      return '$mm/$dd/${d.year} • $h:${d.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }

  Future<void> _execute(Map<String, dynamic> req) async {
    final id = req['id'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Execute alarm?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Apply ${_levelLabel(req['requested_alarm_level'] as String)} to '
          '${(req['area_designation'] as String?) ?? 'this incident'}? '
          'This sets the incident alarm level and notifies responding units.',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('EXECUTE',
                style: TextStyle(color: _green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busyId = id);
    try {
      await _api.executeAlarmRequest(id);
      if (mounted) _toast('Alarm executed.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not execute. Check your connection.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final id = req['id'] as String;
    final reason = await showDialog<String>(
      context: context,
      builder: (dctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Reject alarm request',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: TextStyle(color: AppColors.darkText),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
              child: const Text('REJECT', style: TextStyle(color: _red, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    setState(() => _busyId = id);
    try {
      await _api.rejectAlarmRequest(id, notes: reason.isEmpty ? null : reason);
      if (mounted) _toast('Alarm request rejected.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reject. Check your connection.');
    } finally {
      if (mounted) setState(() => _busyId = null);
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
            _filterRow(),
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
          const Text('Alarm Requests',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Row(
        children: [
          _filterChip('Pending', _pendingOnly),
          const SizedBox(width: 10),
          _filterChip('All', !_pendingOnly),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool on) {
    return GestureDetector(
      onTap: () {
        final pending = label == 'Pending';
        if (pending == _pendingOnly) return;
        setState(() => _pendingOnly = pending);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.accent.withValues(alpha: 0.12) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.accent : const Color(0xFF2A2A2A)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
      return _centered(Icons.cloud_off, _error!, retry: true);
    }
    if (_requests.isEmpty) {
      return _centered(
        Icons.notifications_off_outlined,
        _pendingOnly ? 'No pending alarm requests.' : 'No alarm requests yet.',
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceSolid,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _card(_requests[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> req) {
    final status = (req['status'] as String?) ?? 'pending';
    final (pillText, pillColor) = _statusPill(status);
    final area = (req['area_designation'] as String?)?.toUpperCase() ?? 'INCIDENT';
    final level = _levelLabel(req['requested_alarm_level'] as String);
    final justification = (req['justification'] as String?)?.trim();
    final by = (req['requested_by_name'] as String?) ?? 'Unknown';
    final busy = _busyId == req['id'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(area,
                  style: const TextStyle(
                      color: _label, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pillColor.withValues(alpha: 0.5)),
                ),
                child: Text(pillText,
                    style: TextStyle(color: pillColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(level,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          if (justification != null && justification.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(justification,
                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Text('Requested by $by • ${_fmtWhen(req['created_at'] as String?)}',
              style: const TextStyle(color: _muted, fontSize: 11)),
          if (status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _gradientButton('EXECUTE', busy, () => _execute(req))),
                const SizedBox(width: 12),
                Expanded(child: _outlineButton('REJECT', busy, () => _reject(req))),
              ],
            ),
          ] else if ((req['review_notes'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text('Note: ${req['review_notes']}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _gradientButton(String label, bool busy, VoidCallback onTap) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentText),
              )
            : Text(label,
                style: const TextStyle(
                    color: AppColors.accentText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
      ),
    );
  }

  Widget _outlineButton(String label, bool busy, VoidCallback onTap) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: _red, width: 2),
        ),
        child: Text(label,
            style: const TextStyle(
                color: _red, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
