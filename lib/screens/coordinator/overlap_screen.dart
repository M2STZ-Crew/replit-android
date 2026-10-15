import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/area_map_preview.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'coordinator_feed.dart';

/// Two Areas that have grown into each other (06 · C07): merge them into one
/// incident or keep them separate. The server folds the newer Area (B) into
/// the older (A), and gives the decision 120 s — after that they stay
/// separate on their own.
class OverlapScreen extends StatefulWidget {
  const OverlapScreen({super.key, required this.overlap, required this.feed});

  /// An AreaOverlapItem row.
  final Map<String, dynamic> overlap;
  final CoordinatorFeed feed;

  @override
  State<OverlapScreen> createState() => _OverlapScreenState();
}

class _OverlapScreenState extends State<OverlapScreen> {
  ApiClient get _api => widget.feed.api;
  Map<String, dynamic> get _o => widget.overlap;

  AreaView? _a;
  AreaView? _b;
  bool _busy = false;
  late final DateTime? _expires = parseTime(_o['expires_at']);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _a = widget.feed.byId(_o['area_a_id'] as String);
    _b = widget.feed.byId(_o['area_b_id'] as String);
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final both = await Future.wait([
        _api.getIncident(_o['area_a_id'] as String),
        _api.getIncident(_o['area_b_id'] as String),
      ]);
      if (!mounted) return;
      setState(() {
        _a = AreaView(both[0]);
        _b = AreaView(both[1]);
      });
    } catch (_) {
      // The rows show what the queue already had.
    }
  }

  String _name(String key) {
    final d = (_o[key] as String?) ?? '';
    return d.toLowerCase().startsWith('area') ? d : 'Area $d';
  }

  Duration? get _left {
    final e = _expires;
    if (e == null) return null;
    final d = e.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Future<void> _decide({required bool merge}) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = _o['id'] as String;
    try {
      if (merge) {
        await _api.mergeOverlap(id);
      } else {
        await _api.keepOverlapSeparate(id);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            merge
                ? '${_name('area_b_designation')} merged into '
                      '${_name('area_a_designation')}.'
                : 'Kept as two Areas.',
          ),
        ),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not decide. Check your signal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _name('area_a_designation');
    final b = _name('area_b_designation');
    final metres = (_o['distance_m'] as num?)?.round();
    final left = _left;
    final over = left != null && left == Duration.zero;
    final centres = [?_a?.centre, ?_b?.centre];
    return Scaffold(
      backgroundColor: context.pal.background,
      bottomNavigationBar: ActionBar(
        children: [
          AppButton(
            'Merge into $a',
            run: true,
            busy: _busy,
            onPressed: _busy || over ? null : () => _decide(merge: true),
          ),
          AppButton.secondary(
            'Keep them separate',
            onPressed: _busy || over ? null : () => _decide(merge: false),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: metres == null ? 'Overlap' : 'Overlap · $metres m apart',
              title: 'Merge these Areas?',
              subtitle: metres == null
                  ? '$b has grown into $a.'
                  : '$b has grown to within $metres m of $a.',
            ),
            Expanded(
              child: ScrollFade(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    kScrollFadeEndPadding,
                  ),
                  children: [
                    if (centres.isNotEmpty) ...[
                      AreaMapPreview(centres: centres),
                      const SizedBox(height: 16),
                    ],
                    _row(_a, a),
                    const SizedBox(height: 8),
                    _row(_b, b),
                    const SizedBox(height: 16),
                    InlineAlert(
                      body:
                          'Merging folds $b into $a. The smaller Area becomes '
                          '"merged" and records what it joined. It cannot be '
                          'split again.',
                    ),
                    if (left != null) ...[
                      const SizedBox(height: 12),
                      InlineAlert(
                        tone: over ? AlertTone.danger : AlertTone.warning,
                        title: over
                            ? 'The decision window has closed'
                            : 'Decide within ${_clock(left)}',
                        body: over
                            ? 'They stay as two Areas.'
                            : 'If nobody decides, they stay as two Areas.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _row(AreaView? area, String name) {
    if (area == null) {
      return ListRow(leading: const AgencyPlate(), title: name);
    }
    return AreaPlace(
      area: area,
      builder: (context, place) => ListRow(
        leading: const AgencyPlate(),
        title: name,
        subtitle:
            '${place.street ?? placeLine(area, place)} · '
            '${area.reports == 1 ? '1 report' : '${area.reports} reports'}',
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Eyebrow(
              LifecycleChip.word(area.status),
              color: context.pal.forStatus(area.status),
            ),
            const SizedBox(height: 4),
            Eyebrow(area.bandWord, color: context.pal.label),
          ],
        ),
      ),
    );
  }
}
