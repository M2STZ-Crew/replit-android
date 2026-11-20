import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';

/// The fire codes of one incident (06 · C11b), from the Fire codes row in
/// LIVE's incident drawer. A press records an event on that incident (and
/// tells its units); it never changes the Area's status.
///
/// Until v1.12.56 this was the Codes tab, pressed on whichever incident LIVE
/// showed, and a coordinator could get stuck there (19 Nov 2026: "fire code
/// logical flaw. put it in the incident details drawer"; answered "In the
/// incident's details only"). Opened from an incident, it can only ever be
/// that incident's.
class FireCodesSheet extends StatefulWidget {
  const FireCodesSheet({
    super.key,
    required this.api,
    required this.area,
    required this.presses,
  });

  final ApiClient api;
  final AreaView area;

  /// Fire Volunteer and BFP coordinators press codes ([CoordinatorPowers]);
  /// everyone else reads them.
  final bool presses;

  @override
  State<FireCodesSheet> createState() => _FireCodesSheetState();
}

class _FireCodesSheetState extends State<FireCodesSheet> {
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
      final rows = (await widget.api.getFireCodes()).cast<Map<String, dynamic>>()
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
      if (mounted) setState(() => _error = t('Could not load the fire codes.'));
    }
  }

  Future<void> _press(Map<String, dynamic> code) async {
    final id = code['id'] as String;
    setState(() => _pressing = id);
    try {
      await widget.api.pressFireCode(id, areaId: widget.area.id);
      if (!mounted) return;
      setState(
        () => _recorded = t(
          '{code_number} recorded at {clockText}. Every code press is kept in the audit log.',
          {
            'code_number': code['code_number'],
            'clockText': clockText(DateTime.now()),
          },
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final codes = _codes;
    final presses = widget.presses;
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
            body: t(
              'Fire codes are pressed by Fire Volunteer and BFP '
              'Coordinators. You can see each one here.',
            ),
          )
        else if (_recorded != null)
          InlineAlert(tone: AlertTone.success, body: _recorded!),
        if (!presses || _recorded != null) const SizedBox(height: 16),
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
              opacity: presses ? 1 : AppColors.disabledOpacity,
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
                onTap: !presses || _pressing != null ? null : () => _press(c),
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
