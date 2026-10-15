import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../location/responder_tracker.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'coordinator_feed.dart';
import 'live_incident.dart';

/// The Codes tab (06 · C11b): the fire codes, pressed on the incident LIVE
/// is showing. A press records an event on the incident (and tells its
/// units); it never changes the Area's status.
class CodesTab extends StatefulWidget {
  const CodesTab({super.key, required this.feed, required this.focus});

  final CoordinatorFeed feed;

  /// The Area LIVE is showing, if one was chosen.
  final String? focus;

  @override
  State<CodesTab> createState() => _CodesTabState();
}

class _CodesTabState extends State<CodesTab> {
  ApiClient get _api => widget.feed.api;

  List<Map<String, dynamic>>? _codes;
  String? _error;
  String? _pressing;

  /// The last press, confirmed: "Code A recorded at 9:52 PM."
  String? _recorded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = (await _api.getFireCodes()).cast<Map<String, dynamic>>()
        ..sort(
          (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
            (b['display_order'] as num?) ?? 0,
          ),
        );
      if (mounted) {
        setState(() {
          _codes = [
            for (final c in rows)
              if (c['is_active'] != false) c,
          ];
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the fire codes.');
    }
  }

  Future<void> _press(Map<String, dynamic> code, AreaView area) async {
    final id = code['id'] as String;
    setState(() => _pressing = id);
    try {
      await _api.pressFireCode(id, areaId: area.id);
      if (!mounted) return;
      setState(
        () => _recorded =
            '${code['code_number']} recorded at ${clockText(DateTime.now())}. '
            'Every code press is kept in the audit log.',
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
          const SnackBar(content: Text('Could not record it. Check signal.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pressing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.feed,
        ResponderTracker.instance.sharingFor,
      ]),
      builder: (context, _) {
        final live = [
          for (final a in widget.feed.active)
            if (a.live) a,
          for (final a in widget.feed.active)
            if (!a.live) a,
        ];
        final area = liveFocus(live, widget.focus);
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabHeader(
                eyebrow: area?.name ?? 'No live incident',
                title: 'Fire codes',
                subtitle:
                    'Pressing a code records an event on this incident. It '
                    'does not change the Area status.',
              ),
              Expanded(child: _list(area)),
            ],
          ),
        );
      },
    );
  }

  Widget _list(AreaView? area) {
    final codes = _codes;
    if (codes == null) {
      return _error == null
          ? Center(child: CircularProgressIndicator(color: context.pal.accent))
          : EmptyState(
              title: 'Codes unavailable',
              body: _error!,
              action: AppButton.secondary('Try again', onPressed: _load),
            );
    }
    return ScrollFade(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.paddingOf(context).bottom + kScrollFadeEndPadding,
        ),
        children: [
          if (area == null)
            const InlineAlert(
              body:
                  'Codes are pressed on a live incident. When an Area is '
                  'under way, LIVE shows it and its codes work here.',
            )
          else if (_recorded != null)
            InlineAlert(tone: AlertTone.success, body: _recorded!),
          const SizedBox(height: 16),
          SectionHeader(
            'All codes',
            meta: codes.length == 1 ? '1 code' : '${codes.length} codes',
          ),
          const SizedBox(height: 12),
          for (final c in codes) ...[
            Opacity(
              opacity: area == null ? AppColors.disabledOpacity : 1,
              child: ListRow(
                leading: const _CodePlate(),
                title: (c['name'] as String?) ?? 'Code',
                subtitle: c['description'] as String?,
                trailing: _pressing == c['id']
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.pal.accent,
                        ),
                      )
                    : RowValue(
                        (c['code_number'] as String?) ?? '',
                        color: context.pal.accentInk,
                      ),
                onTap: area == null || _pressing != null
                    ? null
                    : () => _press(c, area),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// The code glyph on the fire plate.
class _CodePlate extends StatelessWidget {
  const _CodePlate();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.pal.wellFor(context.pal.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        AppIcons.gridView,
        size: 20,
        color: context.pal.glyphOn(context.pal.accent),
      ),
    ),
  );
}
