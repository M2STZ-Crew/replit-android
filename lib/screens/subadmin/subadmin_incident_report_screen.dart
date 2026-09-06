import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../../api/api_client.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/incident_map.dart';
import '../../widgets/placeholder_box.dart';
import '../login_screen.dart';
import '../responder/responder_status.dart';
import 'dispatch_units_screen.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _value = AppColors.muted;
const Color _label = AppColors.label;
const Color _red = AppColors.live;

/// Sub-admin's full-screen incident-report / verification view.
///
/// Shows a single citizen report (photo, reporter, time, coordinates, address,
/// verifier) plus a map, and the lifecycle decision actions for the parent
/// incident area. Which actions appear depends on the incident's current status
/// and the sub-admin's agency (only a Fire-Volunteer sub-admin can verify).
class SubAdminIncidentReportScreen extends StatefulWidget {
  const SubAdminIncidentReportScreen({
    super.key,
    required this.report,
    required this.areaId,
    required this.status,
    required this.agency,
    required this.me,
    this.api,
  });

  /// One item from GET /incidents/{id}/reports (reporter_name, photo_url,
  /// device_lat/lng, notes, created_at, ...).
  final Map<String, dynamic> report;

  /// The parent incident (area) id and its last-known status.
  final String areaId;
  final String status;

  /// The signed-in sub-admin's agency_type and /auth/me profile.
  final String? agency;
  final Map<String, dynamic> me;

  final ApiClient? api;

  @override
  State<SubAdminIncidentReportScreen> createState() => _SubAdminIncidentReportScreenState();
}

class _SubAdminIncidentReportScreenState extends State<SubAdminIncidentReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  late String _status = widget.status;
  bool _busy = false;

  String? _address;
  String? _verifiedByName;
  String? _rejectionReason;

  double? get _lat => (widget.report['device_lat'] as num?)?.toDouble();
  double? get _lng => (widget.report['device_lng'] as num?)?.toDouble();

  @override
  void initState() {
    super.initState();
    final lat = _lat;
    final lng = _lng;
    if (lat != null && lng != null) _reverseGeocode(lat, lng);
    _loadDetail();
  }

  // Pull the canonical lifecycle state + verifier name for this incident.
  Future<void> _loadDetail() async {
    try {
      final detail = await _api.getIncident(widget.areaId);
      if (!mounted) return;
      setState(() {
        _status = (detail['status'] as String?) ?? _status;
        _verifiedByName = detail['verified_by_name'] as String?;
        _rejectionReason = detail['rejection_reason'] as String?;
      });
    } catch (_) {
      // keep the status passed in; verifier just stays "---"
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      if (mounted && parts.isNotEmpty) {
        setState(() => _address = parts.take(3).join(', '));
      }
    } catch (_) {
      // address stays null → shows "---"; coordinates are still shown
    }
  }

  // ----------------------------------------------------------- formatting ---
  String _reportedStr(String? iso) {
    if (iso == null) return '---';
    try {
      final d = DateTime.parse(iso).toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      final mins = d.minute.toString().padLeft(2, '0');
      return '$mm - $dd - ${d.year} | ${h.toString().padLeft(2, '0')}:$mins $ampm';
    } catch (_) {
      return '---';
    }
  }

  String _coordStr(double? lat, double? lng) {
    if (lat == null || lng == null) return '---';
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $ns, ${lng.abs().toStringAsFixed(4)}° $ew';
  }

  // -------------------------------------------------------------- actions ---
  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<Map<String, dynamic>> Function() call, String ok) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await call();
      if (!mounted) return;
      _toast(ok);
      navigator.pop(true); // tell the home screen to reload
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Action failed. Check your connection.');
      }
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Reject incident',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Reason (e.g. false report)',
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
              child:
                  const Text('REJECT', style: TextStyle(color: _red, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    _run(() => _api.rejectIncident(widget.areaId, reason), 'Incident rejected.');
  }

  // Open the 2-step dispatch flow (pick trucks → assign crew → dispatch).
  Future<void> _openDispatch() async {
    final dispatched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DispatchUnitsScreen(areaId: widget.areaId)),
    );
    if (dispatched == true && mounted) {
      _toast('Units dispatched.');
      Navigator.of(context).pop(true); // back to home, which reloads
    }
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

  // ---------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: _card(),
                ),
              ),
            ],
          ),
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
            Text('Sub-Admin • ${responderAgencyLabel(widget.agency)}',
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

  Widget _card() {
    final r = widget.report;
    final desc = (r['notes'] as String?)?.trim();
    final reporter = (r['reporter_name'] as String?)?.trim();
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _photo(r['photo_url'] as String?),
          const SizedBox(height: 20),
          ..._fields([
            [desc?.isNotEmpty == true ? desc! : '---', 'DESCRIPTION'],
            [reporter?.isNotEmpty == true ? reporter! : '---', 'REPORTED BY'],
            [_reportedStr(r['created_at'] as String?), 'REPORTED'],
            [_coordStr(_lat, _lng), 'COORDINATES'],
            [_address ?? '---', 'ADDRESS'],
            [_verifiedByName ?? '---', 'VERIFIED BY'],
          ]),
          const SizedBox(height: 20),
          _map(),
          const SizedBox(height: 24),
          _actions(),
        ],
      ),
    );
  }

  Widget _photo(String? url) {
    final image = url == null
        ? const PlaceholderBox(
            width: double.infinity,
            height: double.infinity,
            label: 'NO PHOTO',
            icon: Icons.photo_outlined,
            radius: 14,
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    color: const Color(0x7F303030),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    ),
                  ),
            errorBuilder: (context, error, stack) => const PlaceholderBox(
              width: double.infinity,
              height: double.infinity,
              label: 'PHOTO UNAVAILABLE',
              icon: Icons.broken_image_outlined,
              radius: 14,
            ),
          );

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _panelBorder),
                ),
                child: image,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.line, width: 0.8),
                ),
                child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields(List<List<String>> pairs) {
    final out = <Widget>[];
    for (var i = 0; i < pairs.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 16));
      out.add(Text(
        pairs[i][0],
        style: const TextStyle(color: _value, fontSize: 13, height: 1.38),
      ));
      out.add(const SizedBox(height: 16));
      out.add(Text(
        pairs[i][1],
        style: const TextStyle(
          color: _label,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.80,
          letterSpacing: 1,
        ),
      ));
    }
    return out;
  }

  Widget _map() {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) {
      return const PlaceholderBox(
        width: double.infinity,
        height: 170,
        label: 'NO LOCATION',
        icon: Icons.location_off_outlined,
        radius: 14,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: IncidentMap(lat: lat, lng: lng, zoom: 16),
      ),
    );
  }

  // Lifecycle decision actions, gated by status + agency.
  Widget _actions() {
    final s = _status;
    if (s == 'resolved') {
      return _infoBanner('This incident has been resolved.');
    }
    if (s == 'rejected') {
      return _infoBanner(
        (_rejectionReason?.isNotEmpty == true)
            ? 'Rejected: ${_rejectionReason!}'
            : 'This incident was rejected.',
      );
    }

    final canVerify = s == 'pending' && widget.agency == 'fire_volunteer';
    final dispatchable = const {'verified', 'dispatched', 'en_route', 'arrived'}.contains(s);
    final canReject = s == 'pending' || s == 'verified';

    final children = <Widget>[];
    if (s == 'pending') {
      if (canVerify) {
        children.add(Row(
          children: [
            Expanded(
              child: _gradientButton('VERIFY',
                  () => _run(() => _api.verifyIncident(widget.areaId), 'Incident verified.')),
            ),
            const SizedBox(width: 16),
            Expanded(child: _darkButton('REJECT', _reject)),
          ],
        ));
      } else {
        children.add(_infoBanner('Only a Fire Volunteer sub-admin can verify incidents.'));
        children.add(const SizedBox(height: 12));
        children.add(_darkButton('REJECT', _reject));
      }
    } else if (dispatchable) {
      // Verified onwards: dispatch units, then resolve / reject.
      children.add(_gradientButton('DISPATCH UNITS', _openDispatch));
      children.add(const SizedBox(height: 12));
      final resolve = _darkButton(
          'RESOLVE', () => _run(() => _api.resolveIncident(widget.areaId), 'Incident resolved.'));
      if (canReject) {
        children.add(Row(
          children: [
            Expanded(child: resolve),
            const SizedBox(width: 16),
            Expanded(child: _darkButton('REJECT', _reject)),
          ],
        ));
      } else {
        children.add(resolve);
      }
    } else {
      children.add(_infoBanner('No actions available for this incident.'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _gradientButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: const [
            BoxShadow(color: AppColors.accentTint, blurRadius: 32, offset: Offset(0, 8)),
          ],
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentText),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.accentText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.50,
                  letterSpacing: 1.60,
                ),
              ),
      ),
    );
  }

  Widget _darkButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1.50,
            letterSpacing: 1.60,
          ),
        ),
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
    );
  }
}
