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
import 'responder_status.dart';
import '../../widgets/photo_viewer.dart';
import '../directions_screen.dart';

Color _bg = AppColors.background;
Color _panel = AppColors.glassDim;
Color _panelBorder = AppColors.line;
Color _value = AppColors.muted;
Color _label = AppColors.label;
Color _red = AppColors.live;

/// A responder reviewing a citizen report: photo (tap to zoom), reporter,
/// time, coordinates, address, verifier, a map, and the road route to it.
///
/// v12 §2.5.1: a responder may verify a new report here — the captain may be
/// away from their phone. Rejecting stays with coordinators. Responding (going)
/// happens on the incident screen, where their location starts sharing.
class ResponderIncidentReportScreen extends StatefulWidget {
  const ResponderIncidentReportScreen({
    super.key,
    required this.report,
    required this.areaId,
    required this.status,
    required this.me,
    this.api,
  });

  final Map<String, dynamic> report;
  final String areaId;
  final String status;
  final Map<String, dynamic> me;
  final ApiClient? api;

  @override
  State<ResponderIncidentReportScreen> createState() =>
      _ResponderIncidentReportScreenState();
}

class _ResponderIncidentReportScreenState
    extends State<ResponderIncidentReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  String? _address;
  String? _verifiedByName;
  late String _status = widget.status;
  double? _centroidLat;
  double? _centroidLng;
  bool _busy = false;

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

  Future<void> _loadDetail() async {
    try {
      final detail = await _api.getIncident(widget.areaId);
      if (!mounted) return;
      setState(() {
        _verifiedByName = detail['verified_by_name'] as String?;
        _status = (detail['status'] as String?) ?? _status;
        _centroidLat = (detail['centroid_lat'] as num?)?.toDouble();
        _centroidLng = (detail['centroid_lng'] as num?)?.toDouble();
      });
    } catch (_) {
      // verifier just stays "---"
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
      // address stays "---"; coordinates still show
    }
  }

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
    return Scaffold(
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
        'Responder';
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
              responderAgencyLabel(widget.me['agency_type'] as String?),
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
          if (_routeTo != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _route,
              icon: const Icon(Icons.directions),
              label: const Text('ROUTE TO THE FIRE'),
            ),
          ],
          const SizedBox(height: 24),
          _decision(),
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
              onTap: () => Navigator.of(context).pop(),
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

  /// The fire's position for the route: the incident's centre, or this
  /// report's position before the incident has loaded. Null when neither is
  /// known — then there is no route button, rather than a guessed one.
  ({double lat, double lng})? get _routeTo {
    final lat = _centroidLat ?? _lat;
    final lng = _centroidLng ?? _lng;
    return lat == null || lng == null ? null : (lat: lat, lng: lng);
  }

  void _route() {
    final to = _routeTo;
    if (to == null) return;
    openRouteToFire(context, lat: to.lat, lng: to.lng, name: 'The fire');
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await _api.verifyIncident(widget.areaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verified. Open the incident to respond if you are going.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _loadDetail();
    }
  }

  /// Verify while it is new; after that, where it stands.
  Widget _decision() {
    if (_status == 'reported') {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text(
                  'VERIFY — IT IS A REAL FIRE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      );
    }
    final text = switch (_status) {
      'verified' =>
        'Verified. Open the incident from the feed to respond if you are going.',
      'en_route' || 'arrived' =>
        'Responders are on it. Open the incident to join them.',
      'rejected' => 'A coordinator rejected this report.',
      _ => 'This incident is over.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _panelBorder),
      ),
      child: Text(text, style: TextStyle(color: _value, fontSize: 13)),
    );
  }
}
