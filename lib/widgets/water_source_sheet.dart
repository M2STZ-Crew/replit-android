import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../location/place_names.dart';
import '../models/water_source.dart';
import '../screens/directions_screen.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'design.dart';
import 'field_ops.dart' show ChoiceRow;
import 'no_emoji.dart';

/// Water sources from the staff map (v1.12.55, backend v1.12.43; 19 Nov
/// 2026: "From the map").
///
/// A tap on a hydrant, body of water or cistern opens [WaterSourceSheet]:
/// what it is, its status and who last checked it, and what this account
/// may do with it ([WaterPowers]).
/// - **Directions** for every staff member, by car.
/// - **Update status** for Fire Volunteer and BFP coordinators and
///   responders: a hydrant's, on every map at once.
/// - **Edit details** and **Switch off** for their coordinators. These go to
///   an Admin to approve, and the coordinator is told the answer.
///
/// Their coordinators also add a source at a pin ([proposeWaterSource]).

/// What the water sheet's buttons lead to.
enum WaterAction { directions, status, edit, switchOff }

/// Opens the sheet for [source] and does what was chosen. Completes true
/// when something was saved or sent, so the map reloads the layer.
Future<bool> openWaterSource(
  BuildContext context, {
  required WaterSource source,
  required WaterPowers powers,
  required ApiClient api,
}) async {
  final action = await showFrameSheet<WaterAction>(
    context,
    builder: (_) => WaterSourceSheet(source: source, powers: powers),
  );
  if (action == null || !context.mounted) return false;
  if (action == WaterAction.directions) {
    await openRouteToPlace(
      context,
      lat: source.point.latitude,
      lng: source.point.longitude,
      name: source.title,
      kind: source.kind.marker,
    );
    return false;
  }
  final done = await showFrameSheet<bool>(
    context,
    builder: (_) => switch (action) {
      WaterAction.status => HydrantStatusSheet(source: source, api: api),
      WaterAction.edit => WaterDetailsSheet.edit(source: source, api: api),
      _ => SwitchOffSheet(source: source, api: api),
    },
  );
  if (!context.mounted) return done == true;
  return _saved(
    context,
    done,
    action == WaterAction.status
        ? t('Status saved. It is on every map now.')
        : t('Sent to an Admin to approve. You will be told the answer.'),
  );
}

/// A coordinator's new water source at [point] (the + on their map). Sent to
/// an Admin to approve; completes true when it was sent.
Future<bool> proposeWaterSource(
  BuildContext context, {
  required LatLng point,
  required ApiClient api,
}) async {
  final sent = await showFrameSheet<bool>(
    context,
    builder: (_) => WaterDetailsSheet.add(point: point, api: api),
  );
  if (!context.mounted) return sent == true;
  return _saved(
    context,
    sent,
    t('Sent to an Admin to approve. You will be told the answer.'),
  );
}

/// Says it worked, when it did; true then.
bool _saved(BuildContext context, bool? done, String message) {
  if (done != true) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return true;
}

/// A status's colour: the word carries the meaning, the tone backs it.
Color waterStatusTone(AppPalette pal, WaterStatus status) => switch (status) {
  WaterStatus.operational => pal.ok,
  WaterStatus.nonOperational => pal.live,
  WaterStatus.unknown => pal.muted,
  _ => pal.warn,
};

/// The sheet a tap on a water source opens.
class WaterSourceSheet extends StatelessWidget {
  const WaterSourceSheet({
    super.key,
    required this.source,
    required this.powers,
  });

  final WaterSource source;
  final WaterPowers powers;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final status = source.status;
    final checkedAt = source.checkedAt;
    final by = source.checkedBy;
    final litres = source.capacityLitres;
    final hydrant = source.kind == WaterKind.hydrant;
    void choose(WaterAction action) => Navigator.of(context).pop(action);
    return SheetFrame(
      children: [
        Row(
          children: [
            IconWell(
              tint: pal.water,
              icon: source.kind.marker.glyph,
              size: 40,
              glyph: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Eyebrow(source.kind.noun, color: pal.water),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(source.title, style: context.type.sheetTitle),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          source.address ??
              degrees(source.point.latitude, source.point.longitude),
          style: context.type.bodySm.copyWith(color: pal.textSoft),
        ),
        if (status != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Tag(
              status.word,
              color: waterStatusTone(pal, status),
              dot: true,
            ),
          ),
          if (hydrant) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Tag(
                source.verified ? t('Verified') : t('Not verified'),
                color: source.verified ? pal.ok : pal.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              checkedAt == null
                  ? t('Not checked on the ground yet')
                  : by == null
                  ? t('Checked {when}', {'when': tAgo(checkedAt)})
                  : t('Checked {when} by {by}', {
                      'when': tAgo(checkedAt),
                      'by': by,
                    }),
              style: context.type.caption.copyWith(color: pal.textSoft),
            ),
          ],
        ],
        if (source.kind == WaterKind.water) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Tag(
              source.accessible ? t('Accessible') : t('Restricted'),
              color: source.accessible ? pal.ok : pal.warn,
              dot: true,
            ),
          ),
          if (source.waterType != null) ...[
            const SizedBox(height: 8),
            Text(
              source.waterType!,
              style: context.type.caption.copyWith(color: pal.textSoft),
            ),
          ],
        ],
        if (litres != null) ...[
          const SizedBox(height: 8),
          Text(
            t('{n} litres', {'n': litres}),
            style: context.type.caption.copyWith(color: pal.textSoft),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          t('Directions'),
          icon: AppIcons.directionsCar,
          onPressed: () => choose(WaterAction.directions),
        ),
        if (powers.setStatus && hydrant) ...[
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Update status'),
            icon: AppIcons.factCheck,
            onPressed: () => choose(WaterAction.status),
          ),
        ],
        if (powers.propose) ...[
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Edit details'),
            icon: AppIcons.description,
            onPressed: () => choose(WaterAction.edit),
          ),
          const SizedBox(height: 10),
          AppButton.danger(
            t('Switch off'),
            icon: AppIcons.block,
            onPressed: () => choose(WaterAction.switchOff),
          ),
          const SizedBox(height: 12),
          Text(
            hydrant
                ? t(
                    'Edits and switching off wait for an Admin to approve. '
                    'A status update is on every map at once.',
                  )
                : t('Edits and switching off wait for an Admin to approve.'),
            style: context.type.caption.copyWith(color: pal.textSoft),
          ),
        ],
      ],
    );
  }
}

/// A text box with its label, that drops emoji like every other.
Widget _field(
  BuildContext context, {
  required String label,
  required TextEditingController controller,
  String? hint,
  int maxLength = 200,
  int maxLines = 1,
  bool digits = false,
  ValueChanged<String>? onChanged,
}) => LabeledField(
  label: label,
  builder: (focus) => TextField(
    inputFormatters: [
      const NoEmojiFormatter(),
      if (digits) FilteringTextInputFormatter.digitsOnly,
    ],
    controller: controller,
    focusNode: focus,
    maxLength: maxLength,
    minLines: 1,
    maxLines: maxLines,
    keyboardType: digits ? TextInputType.number : null,
    textCapitalization: digits
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    style: context.type.input,
    decoration: InputDecoration(hintText: hint),
    onChanged: onChanged,
  ),
);

/// Why the server said no, in words someone can act on.
String _failure(Object e) => e is ApiException
    ? e.message
    : t('Could not reach the server. Check your connection and try again.');

/// Update status: what they found when they checked the hydrant. Saved at
/// once; pops true when it was.
class HydrantStatusSheet extends StatefulWidget {
  const HydrantStatusSheet({super.key, required this.source, required this.api});

  final WaterSource source;
  final ApiClient api;

  @override
  State<HydrantStatusSheet> createState() => _HydrantStatusSheetState();
}

class _HydrantStatusSheetState extends State<HydrantStatusSheet> {
  final TextEditingController _note = TextEditingController();
  WaterStatus? _status;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(WaterStatus status) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      await widget.api.setHydrantStatus(
        widget.source.id,
        status.wire,
        notes: note.isEmpty ? null : note,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _failure(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: widget.source.title,
            eyebrowColour: context.pal.water,
            title: t('How is this hydrant?'),
            body: t(
              'Say what you found when you checked it. Everyone on the map '
              'sees it at once, with your organization and the time.',
            ),
          ),
          const SizedBox(height: 16),
          for (final s in WaterStatus.reportable)
            RadioRow(
              label: s.word,
              selected: s == status,
              onTap: () => setState(() => _status = s),
            ),
          const SizedBox(height: 12),
          _field(
            context,
            label: t('What you saw (optional)'),
            controller: _note,
            hint: t('Weak flow at 8 PM'),
            maxLength: 1000,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            InlineAlert(tone: AlertTone.danger, body: _error!),
          ],
          const SizedBox(height: 8),
          AppButton(
            status == null
                ? t('Choose a status')
                : t('Save: {status}', {'status': status.word}),
            busy: _busy,
            onPressed: status == null || _busy ? null : () => _save(status),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Cancel'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Switch off: out of use, off every map once an Admin approves, kept on
/// record. They say why, for the Admin to judge; pops true when sent.
class SwitchOffSheet extends StatefulWidget {
  const SwitchOffSheet({super.key, required this.source, required this.api});

  final WaterSource source;
  final ApiClient api;

  @override
  State<SwitchOffSheet> createState() => _SwitchOffSheetState();
}

class _SwitchOffSheetState extends State<SwitchOffSheet> {
  final TextEditingController _why = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.proposeMapChange(
        layerType: widget.source.kind.layerType,
        operation: 'update',
        targetId: widget.source.id,
        proposedData: {'is_active': false},
        reason: _why.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _failure(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _why.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: widget.source.title,
            eyebrowColour: context.pal.live,
            title: t('Switch this water source off?'),
            body: t(
              'Once an Admin approves, it leaves every map. It stays on '
              'record and can be switched back on.',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            context,
            label: t('Why'),
            controller: _why,
            hint: t('Dried up since October'),
            maxLength: 2000,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            InlineAlert(tone: AlertTone.danger, body: _error!),
          ],
          const SizedBox(height: 8),
          AppButton.danger(
            ready ? t('Send for approval') : t('Say why to send'),
            busy: _busy,
            onPressed: !ready || _busy ? null : _send,
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Cancel'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// A source's details, changed ([WaterDetailsSheet.edit]) or new at a pin
/// ([WaterDetailsSheet.add]); either goes to an Admin. Pops true when sent.
class WaterDetailsSheet extends StatefulWidget {
  const WaterDetailsSheet.edit({
    super.key,
    required WaterSource this.source,
    required this.api,
  }) : point = null;

  const WaterDetailsSheet.add({
    super.key,
    required LatLng this.point,
    required this.api,
  }) : source = null;

  final WaterSource? source;
  final LatLng? point;
  final ApiClient api;

  @override
  State<WaterDetailsSheet> createState() => _WaterDetailsSheetState();
}

class _WaterDetailsSheetState extends State<WaterDetailsSheet> {
  late WaterKind _kind = widget.source?.kind ?? WaterKind.hydrant;
  late final TextEditingController _name = TextEditingController(
    text: widget.source?.name,
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.source?.code,
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.source?.address,
  );
  late final TextEditingController _type = TextEditingController(
    text: widget.source?.waterType,
  );
  late final TextEditingController _litres = TextEditingController(
    text: widget.source?.capacityLitres?.toString(),
  );
  late final TextEditingController _about = TextEditingController(
    text: widget.source?.description,
  );
  late bool _accessible = widget.source?.accessible ?? true;
  final TextEditingController _why = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _adding => widget.source == null;

  @override
  void dispose() {
    for (final c in [_name, _code, _address, _type, _litres, _about, _why]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The fields this kind of source has, as the server names them.
  Map<String, Object?> get _values {
    String? text(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    return switch (_kind) {
      WaterKind.hydrant => {'code': text(_code), 'address': text(_address)},
      WaterKind.water => {
        'name': text(_name),
        'water_type': text(_type),
        'is_accessible': _accessible,
        'description': text(_about),
      },
      WaterKind.cistern => {
        'name': text(_name),
        'code': text(_code),
        'capacity_liters': int.tryParse(_litres.text.trim()),
        'address': text(_address),
        'description': text(_about),
      },
    };
  }

  /// What to send: a new source's every given field and its place; a
  /// change's fields that differ from the record.
  Map<String, Object?> get _proposed {
    final values = _values;
    final source = widget.source;
    if (source == null) {
      final point = widget.point!;
      return {
        'latitude': point.latitude,
        'longitude': point.longitude,
        for (final e in values.entries)
          if (e.value != null) e.key: e.value,
      };
    }
    return {
      for (final e in values.entries)
        if (e.value != source.row[e.key] &&
            !(e.value == null && source.row[e.key] == '') &&
            // A body of water's access is true unless the record says false.
            !(e.key == 'is_accessible' && e.value == source.accessible))
          e.key: e.value,
    };
  }

  /// A body of water needs its name; a change needs something changed.
  bool get _ready {
    if (_kind == WaterKind.water && _values['name'] == null) return false;
    return _adding || _proposed.isNotEmpty;
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final why = _why.text.trim();
      await widget.api.proposeMapChange(
        layerType: _kind.layerType,
        operation: _adding ? 'create' : 'update',
        targetId: widget.source?.id,
        proposedData: _proposed,
        reason: why.isEmpty ? null : why,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _failure(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final point = widget.point;
    void changed(String _) => setState(() {});
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: _adding
                ? degrees(point!.latitude, point.longitude)
                : widget.source!.title,
            eyebrowColour: pal.water,
            title: _adding ? t('Add a water source') : t('Edit details'),
            body: t(
              'An Admin checks it before it changes the map, and you are '
              'told the answer.',
            ),
          ),
          const SizedBox(height: 16),
          if (_adding) ...[
            for (final (i, kind) in WaterKind.values.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              ChoiceRow(
                title: kind.noun,
                icon: kind.marker.glyph,
                tint: pal.water,
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (_kind != WaterKind.hydrant) ...[
            _field(
              context,
              label: _kind == WaterKind.water
                  ? t('Name')
                  : t('Name (optional)'),
              controller: _name,
              hint: _kind == WaterKind.water ? 'Tripa de Gallina' : null,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
          ],
          if (_kind != WaterKind.water) ...[
            _field(
              context,
              label: t('Code (optional)'),
              controller: _code,
              hint: _kind == WaterKind.hydrant ? 'H-17' : null,
              maxLength: 100,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
          ],
          if (_kind == WaterKind.water) ...[
            _field(
              context,
              label: t('Type (optional)'),
              controller: _type,
              hint: t('River, creek, pond'),
              maxLength: 100,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
            ListRow(
              title: t('Accessible'),
              subtitle: t('A fire truck can reach it'),
              trailing: Switch(
                value: _accessible,
                onChanged: (v) => setState(() => _accessible = v),
              ),
              onTap: () => setState(() => _accessible = !_accessible),
            ),
            const SizedBox(height: 12),
          ],
          if (_kind == WaterKind.cistern) ...[
            _field(
              context,
              label: t('Capacity in litres (optional)'),
              controller: _litres,
              maxLength: 9,
              digits: true,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
          ],
          if (_kind != WaterKind.water) ...[
            _field(
              context,
              label: t('Address (optional)'),
              controller: _address,
              hint: 'F. Victor Street, Pasay',
              maxLength: 500,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
          ],
          if (_kind != WaterKind.hydrant) ...[
            _field(
              context,
              label: t('Description (optional)'),
              controller: _about,
              maxLength: 2000,
              maxLines: 3,
              onChanged: changed,
            ),
            const SizedBox(height: 4),
          ],
          _field(
            context,
            label: t('Note for the Admin (optional)'),
            controller: _why,
            maxLength: 2000,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            InlineAlert(tone: AlertTone.danger, body: _error!),
          ],
          const SizedBox(height: 8),
          AppButton(
            _ready
                ? t('Send for approval')
                : _kind == WaterKind.water && _values['name'] == null
                ? t('Name it to send')
                : t('Change something to send'),
            busy: _busy,
            onPressed: !_ready || _busy ? null : _send,
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Cancel'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
