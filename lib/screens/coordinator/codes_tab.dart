import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';
import '../../widgets/code_confirm_sheet.dart';

/// "FC-6 · Water Supply Needed · 2 min ago · Ana Cruz": one press.
String codeLine(Map<String, dynamic> c) {
  final at = parseTime(c['pressed_at']);
  return [
    '${c['code_number'] ?? ''} · ${c['name'] ?? ''}',
    if (at != null) agoText(at),
    ?c['pressed_by_name'] as String?,
  ].join(' · ');
}

/// The fire codes of one incident (06 · C11b), from the Fire codes row in
/// LIVE's incident drawer. A press records an event on that incident (and
/// tells its units); it never changes the Area's status.
///
/// Until v1.12.56 this was the Codes tab, pressed on whichever incident LIVE
/// showed, and a coordinator could get stuck there (19 Nov 2026: "fire code
/// logical flaw. put it in the incident details drawer"; answered "In the
/// incident's details only"). Opened from an incident, it can only ever be
/// that incident's.
///
/// v1.12.59: responders open the same drawer (22 Nov 2026, answered "Same
/// drawer"), pressing only the codes [allowed] lets them, and every press
/// asks first ([confirmFireCode]).
class FireCodesSheet extends StatefulWidget {
  const FireCodesSheet({
    super.key,
    required this.api,
    required this.area,
    required this.presses,
    this.allowed,
    this.readOnlyNote,
    this.declares = false,
  });

  final ApiClient api;
  final AreaView area;

  /// Fire Volunteer and BFP coordinators press codes ([CoordinatorPowers]);
  /// everyone else reads them.
  final bool presses;

  /// Which codes this reader may press, when not all of them: a responder's
  /// (responderMayPress). Null: every code, where [presses].
  final bool Function(String? code)? allowed;

  /// Why a reader who presses none can only read; null for a coordinator's.
  final String? readOnlyNote;

  /// This reader's FC-2 declares the fire under control (v1.12.60): a Fire
  /// Volunteer or BFP coordinator's, not a responder's.
  final bool declares;

  @override
  State<FireCodesSheet> createState() => _FireCodesSheetState();
}

class _FireCodesSheetState extends State<FireCodesSheet> {
  List<Map<String, dynamic>>? _codes;
  String? _error;
  String? _pressing;

  /// The last press, confirmed: "Code A recorded at 9:52 PM."
  String? _recorded;
  final GlobalKey _recordedKey = GlobalKey();

  /// The warning is up: a second tap does not open a second one.
  bool _asking = false;

  /// Every press is shown, not only the latest five.
  bool _allPresses = false;

  /// Pressed from this drawer since it opened, newest first.
  final List<Map<String, dynamic>> _sent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          (await widget.api.getFireCodes()).cast<Map<String, dynamic>>()..sort(
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
      if (mounted) setState(() => _error = t('Could not load the fire codes.'));
    }
  }

  Future<void> _press(Map<String, dynamic> code) async {
    if (_asking) return;
    final id = code['id'] as String;
    final number = (code['code_number'] as String?) ?? t('Code');
    _asking = true;
    final send = await confirmFireCode(
      context,
      number: number,
      name: (code['name'] as String?) ?? '',
      fire: widget.area.name,
      declares: widget.declares && number == 'FC-2',
    );
    _asking = false;
    if (!send || !mounted) return;
    setState(() => _pressing = id);
    try {
      final saved = await widget.api.pressFireCode(id, areaId: widget.area.id);
      if (!mounted) return;
      setState(() {
        _sent.insert(0, {
          'code_number': number,
          'name': code['name'],
          'pressed_at':
              saved['pressed_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'pressed_by_name': saved['pressed_by_name'],
          'id': saved['id'],
        });
        _recorded = t(
          '{code_number} recorded at {clockText}. Every code press is kept in the audit log.',
          {
            'code_number': code['code_number'],
            'clockText': clockText(DateTime.now()),
          },
        );
      });
      _showRecorded();
    } on ApiException catch (e) {
      if (mounted) setState(() => _recorded = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Could not record it. Check signal.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _pressing = null);
    }
  }

  /// The confirmation is at the top, the code pressed often far below it.
  void _showRecorded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _recordedKey.currentContext;
      if (at == null || !at.mounted) return;
      Scrollable.ensureVisible(at, duration: Motion.of(at).state);
    });
  }

  bool _mayPress(Map<String, dynamic> code) =>
      widget.presses &&
      (widget.allowed?.call(code['code_number'] as String?) ?? true);

  @override
  Widget build(BuildContext context) {
    final codes = _codes;
    final presses = widget.presses;
    final pressed = [..._sent, ...widget.area.fireCodes];
    final someClosed = presses && (codes?.any((c) => !_mayPress(c)) ?? false);
    return SheetFrame(
      children: [
        SheetTitles(
          eyebrow: widget.area.name,
          title: t('Fire codes'),
          body: t(
            'Pressing a code records an event on this incident. It does not change the incident\'s status.',
          ),
        ),
        const SizedBox(height: 16),
        if (!presses)
          InlineAlert(
            body:
                widget.readOnlyNote ??
                t(
                  'Fire codes are pressed by Fire Volunteer and BFP '
                  'Coordinators. You can see each one here.',
                ),
          )
        else if (_recorded != null)
          InlineAlert(
            key: _recordedKey,
            tone: AlertTone.success,
            body: _recorded!,
          )
        else if (someClosed)
          InlineAlert(
            body: t(
              'You can press the codes your team may send on this fire. The rest are here to read.',
            ),
          ),
        if (!presses || _recorded != null || someClosed)
          const SizedBox(height: 16),
        // What was pressed already, newest first (v1.12.58).
        if (pressed.isNotEmpty) ...[
          SectionHeader(t('Pressed on this incident')),
          const SizedBox(height: 8),
          for (final c in _allPresses ? pressed : pressed.take(5)) ...[
            Text(codeLine(c), style: context.type.bodySm),
            const SizedBox(height: 6),
          ],
          if (!_allPresses && pressed.length > 5) ...[
            const SizedBox(height: 4),
            AppButton.secondary(
              t('Show all {count}', {'count': pressed.length}),
              height: 48,
              onPressed: () => setState(() => _allPresses = true),
            ),
          ],
          const SizedBox(height: 10),
        ],
        if (codes == null)
          _error == null
              ? const LoadingInline()
              : EmptyState(
                  title: t('Codes unavailable'),
                  body: _error!,
                  action: AppButton.secondary(t('Try again'), onPressed: _load),
                )
        else ...[
          SectionHeader(
            t('All codes'),
            meta: codes.length == 1
                ? t('1 code')
                : t('{count} codes', {'count': codes.length}),
          ),
          const SizedBox(height: 12),
          for (final c in codes) ...[
            Opacity(
              opacity: _mayPress(c) ? 1 : AppColors.disabledOpacity,
              child: ListRow(
                leading: const _CodePlate(),
                title: (c['name'] as String?) ?? t('Code'),
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
                onTap: !_mayPress(c) || _pressing != null
                    ? null
                    : () => _press(c),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
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
