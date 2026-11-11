import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../models/area_view.dart';
import '../models/field_ops.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/field_ops.dart';
import '../widgets/map_layers.dart';
import '../widgets/map_tiles.dart';
import 'camera_capture_screen.dart';
import '../widgets/you_are_here.dart';
import '../widgets/app_icons.dart';
import '../widgets/loading.dart';
import '../i18n/i18n.dart';

/// How far from a fire a neighbour is asked about it: the server's
/// NEIGHBORHOOD_RADIUS_M (app/workers/neighborhood.py; PRD v14 §4.2).
const double kNeighbourAlertMetres = 100;

/// "11 Corroborate" from the REPLIT-OVERHAUL Figma: the 100 m neighbourhood
/// alert (PRD v13 cut it from 50 m), as a screen rather than v2's dialog.
///
/// "Yes" is a real report (v10 §2.2): it opens the same photo step as SOS,
/// with the GPS fix already started when this screen opened. "No, and stop
/// asking" is exactly what POST /notifications/respond `ignore` does — it
/// stops further alerts for this area. The alert the server sends is a fire
/// alert ("Alerto sa Sunog"), so the screen says "a fire".
///
/// "I am safe" (PRD v14 §4.2, §4.11) sits below: a resident the alert reached
/// says so, while the fire is live, and the server keeps it. It is shown only
/// when the server says this resident may answer, and it is never assumed:
/// nothing but that tap records it.
class NeighbourAlertScreen extends StatefulWidget {
  const NeighbourAlertScreen({super.key, required this.areaId, this.api});

  final String areaId;
  final ApiClient? api;

  @override
  State<NeighbourAlertScreen> createState() => _NeighbourAlertScreenState();
}

class _NeighbourAlertScreenState extends State<NeighbourAlertScreen> {
  final MapFollow _follow = MapFollow();

  late final ApiClient _api = widget.api ?? ApiClient();
  final SosLocation _location = SosLocation.instance;

  Map<String, dynamic>? _area;
  String? _street;

  /// The server said this resident may say they are safe.
  bool _maySaySafe = false;
  SafetyAnswer? _answer;
  DateTime? _answeredAt;
  SafetyAnswer? _sendingAnswer;
  String? _answerError;

  Position? get _me => _location.position.value;

  @override
  void initState() {
    super.initState();
    _location.position.addListener(_rebuild);
    // Whichever way they answer, knowing where they are helps: the distance
    // below, and a head start on the fix if the answer is "yes".
    _location.warmUp();
    _load();
    _loadAnswer();
  }

  @override
  void dispose() {
    _location.position.removeListener(_rebuild);
    _follow.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final area = await _api.getArea(widget.areaId);
      if (!mounted) return;
      setState(() => _area = area);
      final c = _centre;
      if (c == null) return;
      final marks = await geo.placemarkFromCoordinates(c.latitude, c.longitude);
      for (final m in marks) {
        for (final s in [m.thoroughfare, m.street]) {
          final v = s?.trim() ?? '';
          if (v.isNotEmpty && !v.contains('+')) {
            if (mounted) setState(() => _street = v);
            return;
          }
        }
      }
    } catch (_) {
      // Without the area or a geocoder the screen still asks the question.
    }
  }

  /// What this resident has said about this fire. With no reply the question
  /// stays hidden: a button the server may refuse is worse than none, and the
  /// hotlines and "Yes, I can see it" do not depend on it.
  Future<void> _loadAnswer() async {
    try {
      final state = await _api.getAlertAnswer(widget.areaId);
      if (!mounted) return;
      final safe = state['response'] == SafetyAnswer.safe.wire;
      setState(() {
        _maySaySafe = state['can_say_safe'] == true;
        _answer = safe ? SafetyAnswer.safe : null;
        _answeredAt = safe ? parseTime(state['responded_at']) : null;
      });
    } catch (_) {}
  }

  Future<void> _saySafe(SafetyAnswer answer) async {
    if (_sendingAnswer != null) return;
    setState(() {
      _sendingAnswer = answer;
      _answerError = null;
    });
    try {
      await _api.respondToAlert(widget.areaId, answer.wire);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _answeredAt = DateTime.now();
        _sendingAnswer = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingAnswer = null;
        _answerError = e is ApiException && e.statusCode != 0
            ? e.message
            : t(
                'Your answer did not reach RepLiT. Check your signal and try '
                'again.',
              );
      });
    }
  }

  Future<void> _call911() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '911'))) return;
    } catch (_) {
      // Said below.
    }
    messenger.showSnackBar(
      SnackBar(content: Text(t('Could not open the dialer for 911.'))),
    );
  }

  LatLng? get _centre {
    final lat = (_area?['centroid_lat'] as num?)?.toDouble();
    final lng = (_area?['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  double? get _metresAway {
    final c = _centre;
    final me = _me;
    if (c == null || me == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(me.latitude, me.longitude),
      c,
    );
  }

  String get _sentence {
    final at = DateTime.tryParse('${_area?['reported_at']}')?.toLocal();
    final metres = kNeighbourAlertMetres.round();
    final street = _street;
    if (street == null) {
      return at == null
          ? t('Someone within {m} metres reported a fire near you.', {
              'm': metres,
            })
          : t('Someone within {m} metres reported a fire near you {ago}.', {
              'm': metres,
              'ago': _ago(at),
            });
    }
    return at == null
        ? t('Someone within {m} metres reported a fire on {street}.', {
            'm': metres,
            'street': street,
          })
        : t('Someone within {m} metres reported a fire on {street} {ago}.', {
            'm': metres,
            'street': street,
            'ago': _ago(at),
          });
  }

  static String _ago(DateTime at) {
    final m = DateTime.now().difference(at).inMinutes;
    if (m < 1) return t('just now');
    if (m == 1) return t('a minute ago');
    if (m < 60) return t('{n} minutes ago', {'n': m});
    final h = m ~/ 60;
    return h == 1 ? t('an hour ago') : t('{n} hours ago', {'n': h});
  }

  void _yes() {
    // Best-effort: the photo report that follows is the real answer, and
    // filing it stops the alerts for this Area by itself.
    unawaited(
      _api.respondToAlert(widget.areaId, 'report').catchError((Object _) {}),
    );
    ReportTiming.instance.start('neighbour_alert');
    _location.warmUp();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
  }

  bool _sending = false;

  Future<void> _no() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.respondToAlert(widget.areaId, 'ignore');
    } catch (_) {
      // Not recorded: the alerts would keep coming, so say so and stay.
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Your answer did not reach RepLiT, so you may be asked again. '
              'Check your connection and try once more.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(t("You won't be asked about this one again."))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          content: [
            Align(alignment: Alignment.centerLeft, child: _alertChip()),
            const SizedBox(height: 24),
            ..._whereLine(),
            Text(t('DO YOU SEE IT TOO?'), style: context.type.display),
            const SizedBox(height: 14),
            Text(_sentence, style: context.type.body),
            const SizedBox(height: 26),
            _proximityMap(),
            const SizedBox(height: 26),
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.info, size: 18, color: context.pal.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t(
                        'Confirming takes you through the same photo step, so '
                        'your answer becomes a real report — not just a tap.',
                      ),
                      style: context.type.caption.copyWith(
                        color: context.pal.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_maySaySafe || _answer != null) ...[
              const SizedBox(height: 26),
              SafetyQuestion(
                choices: const [SafetyAnswer.safe],
                onAnswer: _saySafe,
                answer: _answer,
                answeredAt: _answeredAt == null
                    ? null
                    : clockText(_answeredAt!),
                pendingAnswer: _sendingAnswer,
                error: _answerError,
              ),
              if (_answer == null)
                TextLink(t('Need help now? Call 911'), onTap: _call911),
            ],
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(t('Yes, I can see it'), height: 54, onPressed: _yes),
              const SizedBox(height: 12),
              // Saying they are safe already stopped the alerts.
              if (_answer != null)
                AppButton.secondary(
                  t('Close'),
                  height: 48,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else
                AppButton.secondary(
                  t('No, and stop asking about this'),
                  height: 48,
                  busy: _sending,
                  onPressed: _sending ? null : _no,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "AREA 1.2 · 200 M FROM YOU" over the title, in the accent ink, as the
  /// Figma's nearby alert (10, 10B) has it on both grounds. It was a dark
  /// chip on the map, which the light ground left dark on dark.
  List<Widget> _whereLine() {
    final away = _metresAway;
    final area = (_area?['designation'] as String?)?.trim();
    final parts = [
      if (area != null && area.isNotEmpty) area.toUpperCase(),
      if (away != null)
        t('{distance} FROM YOU', {
          'distance': away < 1000
              ? '${away.round()} M'
              : '${(away / 1000).toStringAsFixed(1)} KM',
        }),
    ];
    if (parts.isEmpty) return const [];
    return [
      Text(
        parts.join(' · '),
        style: context.type.tag.copyWith(
          color: context.pal.accentInk,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _alertChip() {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.pal.live.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.pal.live.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(size: 7),
          const SizedBox(width: 8),
          Text(
            t('NEARBY FIRE ALERT'),
            style: context.type.tag.copyWith(color: context.pal.live),
          ),
        ],
      ),
    );
  }

  /// The reported area, the 100 m its neighbours are asked from, and you.
  Widget _proximityMap() {
    final c = _centre;
    final me = _me;
    // Shorter with "Are you safe?" below it, so "Yes" and "No" stay on a
    // phone's screen. The 100 m circle still fits.
    return Container(
      height: _maySaySafe || _answer != null ? 150 : 226,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.pal.background,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: context.pal.line),
      ),
      child: c == null
          ? LoadingView(
              label: t('Loading the map'),
              mark: false,
              scrollable: false,
            )
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: c,
                    // ~2 m a pixel: the 100 m circle is ~95 px across.
                    initialZoom: 16.1,
                    backgroundColor: context.pal.background,
                    interactionOptions: kMapGestures,
                    onMapEvent: _follow.onMapEvent,
                  ),
                  children: [
                    MapTiles.layer(light: context.pal.isLight),
                    CircleLayer(
                      circles: [
                        MapAreas.incidentRadius(
                          context.pal,
                          c,
                          metres: kNeighbourAlertMetres,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      rotate: true,
                      markers: [
                        Marker(
                          point: c,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.pal.live,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.pal.surfaceSolid,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        if (me != null)
                          Marker(
                            point: LatLng(me.latitude, me.longitude),
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.pal.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.pal.surfaceSolid,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    YouAreHereLayer(follow: _follow),
                    MapLocationButtons(
                      follow: _follow,
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(8),
                    ),
                    MapTiles.attribution(
                      alignment: AttributionAlignment.bottomRight,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
