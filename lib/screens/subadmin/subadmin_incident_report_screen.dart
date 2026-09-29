import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/incident_map.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/placeholder_box.dart';
import '../directions_screen.dart';
import '../login_screen.dart';
import '../responder/responder_status.dart';
import 'post_incident_report_screen.dart';
import 'subadmin_incident_command_screen.dart';

Color _bg = AppColors.background;
Color _panel = AppColors.glassDim;
Color _panelBorder = AppColors.line;
Color _value = AppColors.muted;
Color _label = AppColors.label;
Color _red = AppColors.live;

/// A coordinator reviewing an incident: one citizen report (photo — tap to
/// zoom — reporter, time, coordinates, address, verifier), a map, the road
/// route to the fire, and the decisions (v12 §2.5):
///
/// * new → **Verify** ("this is a real fire"; sends nobody) or **Reject**;
/// * verified → **Respond** ("I am going" — any Fire Volunteer or BFP
///   coordinator may, not only the captain it was meant for), **Fire out**,
///   or **Reject** (a mis-tapped Verify can be undone);
/// * on the way → the same, Reject releasing anyone responding; once someone
///   is on scene, Reject gives way to Fire out.
///
/// It follows the incident on the live socket, so another person's action
/// shows at once, and a button pressed on a stale screen is refused by the
/// server and the screen re-reads.
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
  State<SubAdminIncidentReportScreen> createState() =>
      _SubAdminIncidentReportScreenState();
}

class _SubAdminIncidentReportScreenState
    extends State<SubAdminIncidentReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  late String _status = widget.status;
  bool _busy = false;

  String? _address;
  String? _verifiedByName;
  String? _rejectionReason;

  /// Whether this coordinator is already responding (an active dispatch).
  bool _responding = false;
  double? _centroidLat;
  double? _centroidLng;

  late final LiveRefresh _live = LiveRefresh([
    incidentChannel(widget.areaId),
  ], _loadDetail);

  double? get _lat => (widget.report['device_lat'] as num?)?.toDouble();
  double? get _lng => (widget.report['device_lng'] as num?)?.toDouble();

  @override
  void initState() {
    super.initState();
    final lat = _lat;
    final lng = _lng;
    if (lat != null && lng != null) _reverseGeocode(lat, lng);
    _loadDetail();
    _live.start();
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
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
        _centroidLat = (detail['centroid_lat'] as num?)?.toDouble();
        _centroidLng = (detail['centroid_lng'] as num?)?.toDouble();
      });
    } catch (_) {
      // keep the status passed in; verifier just stays "---"
    }
    try {
      final myId = widget.me['id'];
      final dispatches = await _api.getDispatches(widget.areaId);
      final mine = dispatches.whereType<Map<String, dynamic>>().any(
        (d) => d['responder_id'] == myId && d['status'] == 'active',
      );
      if (mounted) setState(() => _responding = mine);
    } catch (_) {
      // unknown: offer Respond; the server refuses a second one anyway
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();
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

  Future<void> _run(
    Future<Map<String, dynamic>> Function() call,
    String ok,
  ) async {
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
        // Refused because someone else acted first: show what is true now.
        await _loadDetail();
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
          backgroundColor: context.pal.surface,
          title: const Text(
            'Reject incident',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Reason (e.g. false report)',
              hintStyle: TextStyle(color: context.pal.darkText),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text('CANCEL', style: TextStyle(color: context.pal.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
              child: Text(
                'REJECT',
                style: TextStyle(color: _red, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    _run(
      () => _api.rejectIncident(widget.areaId, reason),
      'Incident rejected.',
    );
  }

  /// Verify: stays here, so Respond is one tap away if they are going.
  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await _api.verifyIncident(widget.areaId);
      if (mounted) _toast('Verified. Respond if you are going.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not verify. Check your connection.');
    } finally {
      await _loadDetail();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Respond: this coordinator is going. The command screen takes over —
  /// the live map, the route, and sharing their own location.
  Future<void> _respond() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await _api.selfDispatch(widget.areaId);
      if (!mounted) return;
      _toast('You are responding. Your location is shared while you go.');
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubAdminIncidentCommandScreen(
            areaId: widget.areaId,
            me: widget.me,
            api: _api,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
        await _loadDetail();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not respond. Check your connection.');
      }
    }
  }

  void _route() {
    final lat = _centroidLat ?? _lat;
    final lng = _centroidLng ?? _lng;
    if (lat == null || lng == null) return;
    openRouteToFire(context, lat: lat, lng: lng, name: 'The fire');
  }

  /// Fire out from review: the incident moves to the Post-Incident Report step,
  /// and the report is offered now or left in the tray — the same as from the
  /// command screen.
  Future<void> _fireOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: context.pal.surface,
        title: const Text(
          'Fire out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Mark this incident resolved and stop the response.',
          style: TextStyle(color: context.pal.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('CANCEL', style: TextStyle(color: context.pal.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              'FIRE OUT',
              style: TextStyle(
                color: context.pal.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await _api.resolveIncident(widget.areaId);
      if (!mounted) return;
      await offerPostIncidentReport(context, areaId: widget.areaId, api: _api);
      if (mounted) navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not resolve. Check your connection.');
      }
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
      decoration: BoxDecoration(
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
                color: context.pal.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: context.pal.line),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _accountSheet() {
    final name =
        (widget.me['full_name'] as String?) ??
        (widget.me['email'] as String?) ??
        'Sub-Admin';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.pal.surfaceSolid,
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
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Sub-Admin • ${responderAgencyLabel(widget.agency)}',
              style: TextStyle(color: context.pal.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.logout, color: _red),
              title: const Text(
                'Log out',
                style: TextStyle(color: Colors.white),
              ),
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
          if ((_centroidLat ?? _lat) != null && (_centroidLng ?? _lng) != null)
            ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _route,
                icon: const Icon(Icons.directions),
                label: const Text('ROUTE TO THE FIRE'),
              ),
            ],
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
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.pal.accent,
                        ),
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
            child: GestureDetector(
              // Tap to look closely: full screen, pinch or double-tap to zoom.
              onTap: url == null
                  ? null
                  : () => openPhoto(context, url, label: 'Reported fire photo'),
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
          ),
          if (url != null)
            const Positioned(
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: Icon(Icons.zoom_in, color: Colors.white70, size: 22),
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
                  color: context.pal.glass,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: context.pal.line, width: 0.8),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 22,
                ),
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
      out.add(
        Text(
          pairs[i][0],
          style: TextStyle(color: _value, fontSize: 13, height: 1.38),
        ),
      );
      out.add(const SizedBox(height: 16));
      out.add(
        Text(
          pairs[i][1],
          style: TextStyle(
            color: _label,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.80,
            letterSpacing: 1,
          ),
        ),
      );
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
    if (s == 'post_incident_report') {
      return _infoBanner(
        'Fire out. The Post-Incident Report is still owed — file it from '
        'Pending reports in the menu.',
      );
    }
    if (kAfterFireOut.contains(s)) {
      return _infoBanner(
        s == 'closed'
            ? 'Closed — Post-Incident Report filed.'
            : 'This incident has been resolved.',
      );
    }
    if (s == 'rejected') {
      return _infoBanner(
        (_rejectionReason?.isNotEmpty == true)
            ? 'Rejected: ${_rejectionReason!}'
            : 'This incident was rejected.',
      );
    }

    // v12 §2.5: verify says it is real; respond says "I am going"; reject is
    // open until someone is on scene; fire out ends it.
    final live = const {'verified', 'en_route', 'arrived'}.contains(s);
    final canReject = const {'reported', 'verified', 'en_route'}.contains(s);

    final children = <Widget>[];
    if (s == 'reported') {
      children.add(
        Row(
          children: [
            Expanded(child: _gradientButton('VERIFY', _verify)),
            const SizedBox(width: 16),
            Expanded(child: _darkButton('REJECT', _reject)),
          ],
        ),
      );
    } else if (live) {
      if (_responding) {
        children.add(
          _infoBanner(
            'You are responding. Open the incident from the map for the live '
            'response.',
          ),
        );
      } else {
        children.add(_gradientButton("RESPOND — I'M GOING", _respond));
      }
      children.add(const SizedBox(height: 12));
      final resolve = _darkButton('FIRE OUT', _fireOut);
      if (canReject) {
        children.add(
          Row(
            children: [
              Expanded(child: resolve),
              const SizedBox(width: 16),
              Expanded(child: _darkButton('REJECT', _reject)),
            ],
          ),
        );
      } else {
        children.add(resolve);
      }
    } else {
      children.add(_infoBanner('No actions available for this incident.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
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
          boxShadow: [
            BoxShadow(
              color: context.pal.accentTint,
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accentText,
                ),
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
          border: Border.all(color: context.pal.line),
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
        color: context.pal.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.pal.line),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.pal.muted, fontSize: 13, height: 1.4),
      ),
    );
  }
}
