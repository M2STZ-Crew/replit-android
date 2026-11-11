import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/field_ops.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'design.dart';
import 'sheet_grip.dart';
import '../i18n/i18n.dart';

/// REPLIT (MAIN) 04 · V13 field operations (pass 6): the Choice row, the
/// on-scene Action tile and its Field actions grid, the neighbourhood Safety
/// prompt and roll call, the Help alert, the Fire-out signal, the CIAR
/// status, the Route alternative label, Water level, the Request sheet and
/// the Fire type sheet.
///
/// Every widget here is presentation only. Each act leaves through a
/// callback; a widget never calls the API, never decides an act succeeded,
/// and shows a result only when its caller hands one back. Where the backend
/// has no endpoint yet (PRD v13 §17.3) the screens that use these stay out of
/// the live app; see docs/FRONTEND_INTEGRATION_HANDOFF.md.

/// Lays out the eyebrow, prompt and body a pass 6 sheet opens with.
class _SheetHead extends StatelessWidget {
  const _SheetHead({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow, color: context.pal.accentInk),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(title, style: context.type.sheetTitle),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: context.type.body.copyWith(color: context.pal.textSoft),
        ),
      ],
    );
  }
}

/// A sheet's surface: 20px top corners, the grabber, 24px sides and the
/// home indicator's clearance (04 · Request sheet, Fire type sheet).
class _PassSixSheet extends StatelessWidget {
  const _PassSixSheet({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          border: Border(top: BorderSide(color: context.pal.line)),
        ),
        // The grabber stays put; a long sheet scrolls under it.
        child: FrozenHandleSheet(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 34 + inset),
          handlePadding: const EdgeInsets.only(top: 12, bottom: 16),
          handleColor: context.pal.lineStrong,
          children: children,
        ),
      ),
    );
  }
}

/// The filled check badge, or the empty ring, at a Choice row's end.
class _ChoiceIndicator extends StatelessWidget {
  const _ChoiceIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context).state,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSolid : null,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: context.pal.lineStrong, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(AppIcons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// One option in a choice list on a sheet (04 · Choice row): fire type and
/// subtype, decline category, backup agency, a safety answer. The whole row
/// is the target (≥ 56px). Selected is three cues — the coral tint, a 1.5px
/// coral edge and the filled check — never colour alone. A null [onTap]
/// draws it disabled at 38 %.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.meta,
    this.icon,
    this.tint,
    this.leading,
    this.multiple = false,
  });

  final String title;
  final String? meta;

  /// The Icon plate's glyph; with [tint] it takes the tone's plate and edge.
  final IconData? icon;
  final Color? tint;

  /// A leading widget in place of the Icon plate (an Agency plate).
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  /// One of many may be picked (a checkbox), not one of a group (a radio).
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final enabled = onTap != null;
    final shape = BorderRadius.circular(AppRadius.control);
    final lead =
        leading ?? (icon == null ? null : IconPlate(icon!, tint: tint));
    return Semantics(
      button: true,
      enabled: enabled,
      checked: selected,
      inMutuallyExclusiveGroup: !multiple,
      label: meta == null ? title : '$title. $meta',
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : AppColors.disabledOpacity,
        child: Material(
          color: Colors.transparent,
          borderRadius: shape,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            highlightColor: pal.pressed,
            splashColor: pal.pressed,
            child: AnimatedContainer(
              duration: Motion.of(context).state,
              curve: Motion.standard,
              constraints: const BoxConstraints(minHeight: 56),
              padding: EdgeInsets.fromLTRB(lead == null ? 16 : 8, 8, 16, 8),
              decoration: BoxDecoration(
                color: selected
                    ? pal.accent.withValues(alpha: 0.16)
                    : pal.surface,
                borderRadius: shape,
                border: Border.all(
                  color: selected ? pal.accent : pal.line,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (lead != null) ...[lead, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: context.type.listTitle),
                        if (meta != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta!,
                            style: context.type.detail.copyWith(
                              color: pal.label,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ChoiceIndicator(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large on-scene request button (04 · Action tile): its own icon plate,
/// a name and what it does. Locked until the fire type is picked (PRD v13
/// §4.5.3) — the meta line then says why, and the tile cannot be pressed.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
    required this.onTap,
    this.locked = false,
    this.lockedMeta = 'Pick the fire type first',
  });

  final IconData icon;
  final String title;
  final String meta;
  final bool locked;
  final String lockedMeta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.card);
    final active = !locked && onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: '$title. ${t(locked ? lockedMeta : meta)}',
      excludeSemantics: true,
      onTap: active ? onTap : null,
      child: Material(
        color: pal.surface,
        borderRadius: shape,
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: shape,
          highlightColor: pal.pressed,
          splashColor: pal.pressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: locked ? pal.line : pal.lineStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconPlate(
                  locked ? AppIcons.lock : icon,
                  tint: locked ? null : pal.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: context.type.rowTitleLg.copyWith(
                    color: locked ? pal.label : pal.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(locked ? lockedMeta : meta),
                  style: context.type.detail.copyWith(color: pal.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four on-scene requests as a 2 × 2 grid under "On-scene requests"
/// (04 · Field actions). Locked until a fire type is set; [fireType] then
/// names it on the right. Each tile hands its request type to [onRequest].
class FieldActions extends StatelessWidget {
  const FieldActions({super.key, required this.onRequest, this.fireType});

  /// The confirmed classification; null keeps every tile locked.
  final FireClassification? fireType;
  final ValueChanged<FieldRequestType> onRequest;

  static const _tiles = [
    (FieldRequestType.water, AppIcons.waterDrop, 'Request to your Admin'),
    (FieldRequestType.equipment, AppIcons.construction, 'Say what you need'),
    (FieldRequestType.backup, AppIcons.groupAdd, 'Pick an agency'),
    (FieldRequestType.escalation, AppIcons.trendingUp, 'Your Admin asks BFP'),
  ];

  @override
  Widget build(BuildContext context) {
    final locked = fireType == null;
    Widget tile(int i) {
      final (type, icon, meta) = _tiles[i];
      return Expanded(
        child: ActionTile(
          icon: icon,
          title: t(type.label),
          meta: t(meta),
          locked: locked,
          onTap: () => onRequest(type),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          t('On-scene requests'),
          meta: locked
              ? t('Locked')
              : t('Unlocked · {label}', {'label': fireType!.label}),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tile(0), const SizedBox(width: 12), tile(1)],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tile(2), const SizedBox(width: 12), tile(3)],
          ),
        ),
        if (locked) ...[
          const SizedBox(height: 12),
          Text(
            t(
              'Pick the fire type to unlock requests. Arrived is recorded '
              'already.',
            ),
            style: context.type.detail.copyWith(color: context.pal.label),
          ),
        ],
      ],
    );
  }
}

/// What the neighbourhood card shows once "Are you safe?" has an answer.
class _SafetyResult extends StatelessWidget {
  const _SafetyResult({required this.answer, required this.at});

  final SafetyAnswer answer;
  final String at;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (
      Color? tone,
      IconData icon,
      String title,
      String body,
    ) = switch (answer) {
      SafetyAnswer.safe => (
        pal.ok,
        AppIcons.healthAndSafety,
        t('You’re marked safe · {at}', {'at': at}),
        t('Recorded for this fire. You won’t be alerted about it again.'),
      ),
      SafetyAnswer.needHelp => (
        pal.live,
        AppIcons.frontHand,
        t('Help requested · {at}', {'at': at}),
        t(
          'The responding Captain now sees your location and phone '
          'number. In danger right now? Call 911.',
        ),
      ),
      SafetyAnswer.notInArea => (
        null,
        AppIcons.locationOff,
        t('You’re not in the area'),
        t('No more alerts or roll call for this Area.'),
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone == null ? pal.background : pal.statusTint(tone),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: tone ?? pal.lineStrong),
        ),
        child: Row(
          children: [
            IconPlate(icon, tint: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.rowTitleLg),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: context.type.detail.copyWith(color: pal.textSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 100 m neighbourhood card (04 · Safety prompt; PRD v13 §4.2, §12.1):
/// "Do you see it too?" — Report or Ignore — and, below a hairline, "Are you
/// safe?" — I am safe, I need help, Not in the area. An answered state
/// replaces the three choices with what happened. "I need help" reaches the
/// responding Coordinator only (§9.4).
///
/// The safety half shows only when [onSafety] is given.
class SafetyPromptCard extends StatelessWidget {
  const SafetyPromptCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.place,
    required this.onReport,
    required this.onIgnore,
    this.reporting = false,
    this.ignoring = false,
    this.onSafety,
    this.answer,
    this.answeredAt,
    this.pendingAnswer,
    this.safetyError,
  });

  /// "Area 1.2 · 80 m from you".
  final String eyebrow;

  /// "Fire reported near your home".
  final String title;

  /// "F. Victor Street, Barangay 76 · 9:41 PM".
  final String place;
  final VoidCallback? onReport;
  final VoidCallback? onIgnore;
  final bool reporting;
  final bool ignoring;

  /// Sends a safety answer; null hides "Are you safe?".
  final ValueChanged<SafetyAnswer>? onSafety;

  /// The answer the server has recorded, and when ("9:43").
  final SafetyAnswer? answer;
  final String? answeredAt;

  /// The answer being sent; its row shows selected while it goes.
  final SafetyAnswer? pendingAnswer;

  /// Why the last answer did not save; the choices stay open to try again.
  final String? safetyError;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final question = context.type.label.copyWith(color: pal.textSoft);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconPlate(AppIcons.localFireDepartment, tint: pal.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow, color: pal.accentInk),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text(title, style: context.type.listTitle),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place,
                      style: context.type.detail.copyWith(color: pal.label),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t('Do you see it too?'), style: question),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  t('Report'),
                  busy: reporting,
                  onPressed: ignoring ? null : onReport,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  t('Ignore'),
                  busy: ignoring,
                  onPressed: reporting ? null : onIgnore,
                ),
              ),
            ],
          ),
          if (onSafety != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: pal.line),
            const SizedBox(height: 14),
            SafetyQuestion(
              onAnswer: onSafety!,
              answer: answer,
              answeredAt: answeredAt,
              pendingAnswer: pendingAnswer,
              error: safetyError,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Are you safe?": the choices, or once answered what the answer did. One tap
/// sends it, so the choices lock while it goes and a failure leaves them open.
///
/// [choices] says which to offer. The live alert offers only "I am safe": the
/// server does not take the others yet, and "I need help" promises the
/// responding Captain sees where you are, which must be true before it is said.
class SafetyQuestion extends StatelessWidget {
  const SafetyQuestion({
    super.key,
    required this.onAnswer,
    this.choices = SafetyAnswer.values,
    this.answer,
    this.answeredAt,
    this.pendingAnswer,
    this.error,
  });

  final ValueChanged<SafetyAnswer> onAnswer;
  final List<SafetyAnswer> choices;

  /// The answer the server has recorded, and when ("9:43").
  final SafetyAnswer? answer;
  final String? answeredAt;

  /// The answer being sent; its row shows selected while it goes.
  final SafetyAnswer? pendingAnswer;

  /// Why the last answer did not save.
  final String? error;

  static const _rows = [
    (
      SafetyAnswer.safe,
      'I am safe',
      'Tell responders you are out of danger',
      AppIcons.healthAndSafety,
    ),
    (
      SafetyAnswer.needHelp,
      'I need help',
      'The responding Captain sees where you are',
      AppIcons.frontHand,
    ),
    (
      SafetyAnswer.notInArea,
      'Not in the area',
      'No more alerts for this Area',
      AppIcons.locationOff,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final sending = pendingAnswer != null;
    final rows = _rows.where((r) => choices.contains(r.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t('Are you safe?'),
          style: context.type.label.copyWith(color: pal.textSoft),
        ),
        const SizedBox(height: 8),
        if (answer != null)
          _SafetyResult(answer: answer!, at: answeredAt ?? '')
        else ...[
          for (final (i, (value, label, meta, icon)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            ChoiceRow(
              title: t(label),
              meta: t(meta),
              icon: icon,
              tint: switch (value) {
                SafetyAnswer.safe => pal.ok,
                SafetyAnswer.needHelp => pal.live,
                SafetyAnswer.notInArea => null,
              },
              selected: pendingAnswer == value,
              onTap: sending ? null : () => onAnswer(value),
            ),
          ],
          if (sending) ...[
            const SizedBox(height: 8),
            Text(
              t('Saving your answer…'),
              style: context.type.detail.copyWith(color: pal.label),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            InlineAlert(body: error!, tone: AlertTone.danger),
          ],
        ],
      ],
    );
  }
}

/// The Area's safety roll call (04 · V13 field operations): how many said
/// they are safe, need help or are away, and when it was counted.
class SafetyRollCallStrip extends StatelessWidget {
  const SafetyRollCallStrip({
    super.key,
    required this.rollCall,
    required this.title,
    this.updated,
  });

  final SafetyRollCall rollCall;

  /// "Safety roll call · 100 m" — the radius is the server's, so the caller
  /// names it.
  final String title;

  /// "Updated 9:47".
  final String? updated;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget count(int n, String label, Color dot) => Expanded(
      child: Semantics(
        label: '$n $label',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: pal.background,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$n', style: context.type.rowTitleLg),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(color: pal.label),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(title, color: pal.label)),
              if (updated != null)
                Text(
                  updated!,
                  style: context.type.caption.copyWith(color: pal.label),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              count(rollCall.safe, t('Safe'), pal.ok),
              const SizedBox(width: 8),
              count(rollCall.needHelp, t('Need help'), pal.live),
              const SizedBox(width: 8),
              count(rollCall.notInArea, t('Not in area'), pal.muted),
            ],
          ),
        ],
      ),
    );
  }
}

/// A resident's "I need help" on the responding Coordinator's screen (04 ·
/// Help alert; PRD v13 §4.2, §9.4): where they are and how to reach them,
/// with Call and Show on map. New until the Coordinator has seen it.
class HelpAlertCard extends StatelessWidget {
  const HelpAlertCard({
    super.key,
    required this.raisedAt,
    required this.where,
    required this.contact,
    required this.onCall,
    required this.onShowOnMap,
    this.seenAt,
  });

  /// "9:43 PM".
  final String raisedAt;

  /// "62 m north-east of Area 1.2 · Leveriza Street".
  final String where;
  final String contact;
  final VoidCallback? onCall;
  final VoidCallback? onShowOnMap;

  /// When this Coordinator saw it; null while it is new.
  final String? seenAt;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fresh = seenAt == null;
    return Semantics(
      container: true,
      liveRegion: fresh,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fresh ? pal.statusTint(pal.live) : pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: fresh ? pal.live : pal.lineStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconPlate(AppIcons.frontHand, tint: pal.live),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        fresh
                            ? t('Need help · {raisedAt}', {
                                'raisedAt': raisedAt,
                              })
                            : t('Seen {seenAt}', {'seenAt': seenAt}),
                        color: fresh ? pal.live : pal.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('Resident needs help'),
                        style: context.type.listTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        where,
                        style: context.type.detail.copyWith(
                          color: pal.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  t('Contact'),
                  style: context.type.detail.copyWith(color: pal.label),
                ),
                const Spacer(),
                Text(
                  contact,
                  style: context.type.rowValue.copyWith(
                    color: pal.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    t('Call'),
                    icon: AppIcons.call,
                    onPressed: onCall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton.secondary(
                    t('Show on map'),
                    icon: AppIcons.locationOn,
                    onPressed: onShowOnMap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'Visible to the responding Captain only — never to other '
                'residents.',
              ),
              style: context.type.caption.copyWith(color: pal.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ring that pulses round the Fire-out signal's core. Still under reduced
/// motion; the words carry the state.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.active});

  final bool active;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && !Motion.of(context).reduced;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox.square(
      dimension: 44,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final phase = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 30 + 14 * (widget.active ? (phase == 0 ? 1 : phase) : 1),
                height:
                    30 + 14 * (widget.active ? (phase == 0 ? 1 : phase) : 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (widget.active ? pal.ok : pal.lineStrong).withValues(
                      alpha: widget.active && phase > 0 ? 1 - phase : 1,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.markerShelterSurface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            AppIcons.fireExtinguisher,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Citizens' "Fire looks out" votes reaching the threshold, on the
/// Coordinator's screen (04 · Fire-out signal; PRD v13 §4.11). A signal, not
/// a decision: only the Coordinator marks fire out.
class FireOutSignalCard extends StatelessWidget {
  const FireOutSignalCard({
    super.key,
    required this.votes,
    required this.window,
    this.seenAt,
  });

  final int votes;

  /// "within 100 m in the last 10 min" — the server's threshold, named by the
  /// caller.
  final String window;

  /// "9:52 PM" once seen; null while it is new and pulsing.
  final String? seenAt;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fresh = seenAt == null;
    final residents = votes == 1
        ? t('1 resident')
        : t('{votes} residents', {'votes': votes});
    return Semantics(
      container: true,
      liveRegion: fresh,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fresh ? pal.statusTint(pal.ok) : pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: fresh ? pal.ok : pal.lineStrong),
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: _Pulse(active: fresh)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fresh
                        ? t('Citizens report fire out')
                        : t('{residents} said the fire looks out', {
                            'residents': residents,
                          }),
                    style: context.type.listTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fresh
                        ? t(
                            '{residents} {window}. Only you can mark fire out.',
                            {'residents': residents, 'window': window},
                          )
                        : t(
                            'Seen {seenAt}. Mark fire out once you have confirmed it on scene.',
                            {'seenAt': seenAt},
                          ),
                    style: context.type.detail.copyWith(color: pal.textSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reserved slot for Lit, the mascot (04 · Lit placeholder): its artwork
/// is "final design TBD", so no character is drawn.
class LitPlaceholder extends StatelessWidget {
  const LitPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _DashedCircle(pal.accent),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: pal.accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            t('Lit'),
            style: context.type.label.copyWith(color: pal.accentInk),
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const dashes = 24;
    const sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.75), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCircle old) => old.colour != colour;
}

/// The CIAR after fire out (04 · CIAR status; PRD v13 §4.8): Lit while it is
/// written, what to do when it could not be, and View once it is attached.
/// There is no regenerate — the CIAR is immutable; corrections go on record.
class CiarStatusCard extends StatelessWidget {
  const CiarStatusCard({
    super.key,
    required this.state,
    required this.reference,
    this.lockedAt,
    this.onView,
  });

  final CiarState state;

  /// "IR-2026-00142".
  final String reference;

  /// "10:24 PM", when [state] is ready.
  final String? lockedAt;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (title, body) = switch (state) {
      CiarState.generating => (
        t('Writing the CIAR'),
        t(
          'Lit is composing the formal report from your Post-Incident Report. '
          'Usually under 10 seconds.',
        ),
      ),
      CiarState.failed => (
        t('The CIAR couldn’t be generated'),
        t(
          'Your Post-Incident Report is saved. Tell your Admin and quote the '
          'reference above.',
        ),
      ),
      CiarState.ready => (
        t('CIAR attached'),
        t(
          'Locked {value}. Every agency on this Area can read it. It is never edited — corrections go on record.',
          {'value': lockedAt ?? ''},
        ),
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: state == CiarState.failed
              ? pal.statusTint(pal.live)
              : pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: switch (state) {
              CiarState.generating => pal.line,
              CiarState.failed => pal.live,
              CiarState.ready => pal.lineStrong,
            },
          ),
        ),
        child: Row(
          children: [
            switch (state) {
              CiarState.generating => const LitPlaceholder(),
              CiarState.failed => IconPlate(AppIcons.error, tint: pal.live),
              CiarState.ready => IconPlate(AppIcons.description, tint: pal.ok),
            },
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    t('CIAR · {reference}', {'reference': reference}),
                    color: pal.label,
                  ),
                  const SizedBox(height: 2),
                  Text(title, style: context.type.listTitle),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: context.type.detail.copyWith(color: pal.textSoft),
                  ),
                ],
              ),
            ),
            if (state == CiarState.ready && onView != null) ...[
              const SizedBox(width: 8),
              TextLink(t('View'), onTap: onView!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The fill colour a water level is drawn in: none at 0 %, amber while low
/// (5–25 %), water blue above.
Color _waterFill(AppPalette pal, int pct) =>
    WaterLevel.low(pct) ? pal.warn : pal.water;

/// The level's header: what is measured, and the percentage — red "0 % — not
/// usable" when it is empty.
class _WaterHeader extends StatelessWidget {
  const _WaterHeader({required this.label, required this.pct});

  final String label;
  final int pct;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final empty = !WaterLevel.usable(pct);
    return Row(
      children: [
        Expanded(
          child: Text(
            t(label),
            style: context.type.label.copyWith(color: pal.textSoft),
          ),
        ),
        Text(
          empty ? t('0% · not usable') : '$pct%',
          style: context.type.rowValue.copyWith(
            color: empty ? pal.live : pal.onBackground,
          ),
        ),
      ],
    );
  }
}

/// A water source's level, for reading (04 · Water level, Style=Bar; PRD v13
/// §4.9.6): 0 % is not usable, 5–25 % low, 30–100 % in water blue.
class WaterLevelBar extends StatelessWidget {
  const WaterLevelBar({
    super.key,
    required this.pct,
    this.label = 'Water level',
  }) : assert(pct >= 0 && pct <= 100);

  final int pct;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      label: t(label),
      value: WaterLevel.usable(pct)
          ? t('{pct} percent', {'pct': pct})
          : t('0 percent, not usable'),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _WaterHeader(label: label, pct: pct),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: pal.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pal.lineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct / 100,
              child: pct == 0
                  ? null
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: _waterFill(pal, pct),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The level for updating (04 · Water level, Style=Slider): the thumb snaps
/// to 5 % steps; the steps and the rule are spelt out underneath.
class WaterLevelSlider extends StatelessWidget {
  const WaterLevelSlider({
    super.key,
    required this.pct,
    required this.onChanged,
    this.label = 'Water level',
  }) : assert(pct >= 0 && pct <= 100);

  final int pct;

  /// Null draws it read-only.
  final ValueChanged<int>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final steps = context.type.caption.copyWith(color: pal.label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: _WaterHeader(label: label, pct: pct),
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            trackShape: _WaterTrack(
              inset: pal.background,
              edge: pal.lineStrong,
              fill: _waterFill(pal, pct),
            ),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 13,
              disabledThumbRadius: 13,
              elevation: 0,
              pressedElevation: 0,
            ),
            thumbColor: pal.onBackground,
            disabledThumbColor: pal.muted,
            overlayColor: pal.accent.withValues(alpha: 0.16),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
            padding: EdgeInsets.zero,
          ),
          child: SizedBox(
            height: 44,
            child: Slider(
              value: pct.toDouble(),
              min: 0,
              max: 100,
              divisions: 100 ~/ WaterLevel.step,
              label: '$pct%',
              semanticFormatterCallback: (v) {
                final p = WaterLevel.snap(v);
                return p == 0
                    ? t('0 percent, not usable')
                    : t('{p} percent', {'p': p});
              },
              onChanged: onChanged == null
                  ? null
                  : (v) {
                      final p = WaterLevel.snap(v);
                      if (p != pct) HapticFeedback.selectionClick();
                      onChanged!(p);
                    },
            ),
          ),
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in const ['0%', '25%', '50%', '75%', '100%'])
                Text(s, style: steps),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t('Moves in 5% steps. 0% marks the source as not usable.'),
          style: steps,
        ),
      ],
    );
  }
}

/// The slider's track: the inset ground with the control edge, filled from
/// the left in the level's colour.
class _WaterTrack extends SliderTrackShape with BaseSliderTrackShape {
  const _WaterTrack({
    required this.inset,
    required this.edge,
    required this.fill,
  });

  final Color inset;
  final Color edge;
  final Color fill;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final canvas = context.canvas;
    canvas.drawRRect(r, Paint()..color = inset);
    final filled = Rect.fromLTRB(
      rect.left,
      rect.top,
      thumbCenter.dx,
      rect.bottom,
    );
    if (filled.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(filled, const Radius.circular(6)),
        Paint()..color = fill,
      );
    }
    canvas.drawRRect(
      r,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// The urgency chips every request but escalation asks for.
class _UrgencyChips extends StatelessWidget {
  const _UrgencyChips({required this.value, required this.onChanged});

  final Urgency? value;
  final ValueChanged<Urgency>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Urgency'),
          style: context.type.label.copyWith(color: context.pal.textSoft),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final u in Urgency.values)
              PickChip(
                label: u.label,
                selected: value == u,
                onTap: onChanged == null ? () {} : () => onChanged!(u),
              ),
          ],
        ),
      ],
    );
  }
}

/// The on-scene request sheets (04 · Request sheet; PRD v13 §4.5.3, §4.7):
/// Need water (amount, urgency), Need equipment (what, urgency), Need backup
/// (agency, urgency), Alarm escalation (proposed level). On mobile every
/// request goes to the sender's own Admin; the Admins forward it on the web.
///
/// [onSend] owns the request: the sheet shows Sending while its future runs,
/// closes with the request when it completes, and keeps everything typed and
/// says what went wrong when it throws.
class RequestSheet extends StatefulWidget {
  const RequestSheet({
    super.key,
    required this.type,
    required this.eyebrow,
    required this.recipient,
    required this.onSend,
    this.currentLevel = '1st Alarm',
  });

  final FieldRequestType type;

  /// "Area 1.2 — on scene · Structural".
  final String eyebrow;

  /// "Goes to your Admin — Pasay Fire Volunteers · Area 1.2 attached".
  final String recipient;

  /// The level an escalation starts above.
  final String currentLevel;
  final Future<void> Function(FieldRequest request) onSend;

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _text = TextEditingController();
  Urgency? _urgency;
  BackupAgency? _agency;
  String? _level;
  bool _tried = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? get _missing => switch (widget.type) {
    FieldRequestType.water when _text.text.trim().isEmpty => t(
      'Enter an estimate, like 2,000 litres.',
    ),
    FieldRequestType.equipment when _text.text.trim().isEmpty => t(
      'Say what you need, like a 10 m ladder.',
    ),
    FieldRequestType.backup when _agency == null => t(
      'Pick the agency to ask.',
    ),
    FieldRequestType.escalation when _level == null => t('Pick a level.'),
    FieldRequestType.water ||
    FieldRequestType.equipment ||
    FieldRequestType.backup when _urgency == null => t(
      'Pick how urgent it is.',
    ),
    _ => null,
  };

  FieldRequest _request() => switch (widget.type) {
    FieldRequestType.water => FieldRequest.water(
      amount: _text.text.trim(),
      urgency: _urgency!,
    ),
    FieldRequestType.equipment => FieldRequest.equipment(
      equipment: _text.text.trim(),
      urgency: _urgency!,
    ),
    FieldRequestType.backup => FieldRequest.backup(
      agency: _agency!,
      urgency: _urgency!,
    ),
    FieldRequestType.escalation => FieldRequest.escalation(level: _level!),
  };

  Future<void> _send() async {
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_missing != null || _sending) return;
    final request = _request();
    setState(() => _sending = true);
    try {
      await widget.onSend(request);
      if (mounted) Navigator.of(context).pop(request);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = t(
          'Your request was not sent. Check your connection and send '
          'it again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final missing = _tried ? _missing : null;
    final (String title, String body, String send) = switch (widget.type) {
      FieldRequestType.water => (
        t('Need water'),
        t(
          'Your Admin sees this at once and can ask other organizations for '
          'water.',
        ),
        t('Send request'),
      ),
      FieldRequestType.equipment => (
        t('Need equipment'),
        t('Say exactly what you need. Your Admin passes it on.'),
        t('Send request'),
      ),
      FieldRequestType.backup => (
        t('Need backup'),
        t('Pick the agency. Your Admin asks that agency’s Admins.'),
        t('Send request'),
      ),
      FieldRequestType.escalation => (
        t('Request alarm escalation'),
        t('Your Admin sends this to BFP Pasay. Only BFP sets the alarm level.'),
        t('Send escalation request'),
      ),
    };
    final editable = !_sending;
    final above = kAlarmLevels.indexOf(widget.currentLevel);

    return _PassSixSheet(
      children: [
        _SheetHead(eyebrow: widget.eyebrow, title: title, body: body),
        const SizedBox(height: 16),
        switch (widget.type) {
          FieldRequestType.water => _field(
            label: t('Estimated amount'),
            helper: t('Rough is fine — gallons or litres.'),
            hint: t('e.g. 2,000 litres'),
            multiline: false,
            editable: editable,
          ),
          FieldRequestType.equipment => _field(
            label: t('What do you need?'),
            helper: t('Free text for now. A picker may replace it later.'),
            hint: t('e.g. Extension ladder, 10 m. Two SCBA sets.'),
            multiline: true,
            editable: editable,
          ),
          FieldRequestType.backup => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Which agency?'),
                style: context.type.label.copyWith(color: pal.textSoft),
              ),
              const SizedBox(height: 8),
              for (final (i, a) in BackupAgency.values.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                ChoiceRow(
                  title: a.label,
                  meta: a.recipients,
                  leading: AgencyPlate(agency: a.agency),
                  selected: _agency == a,
                  onTap: editable ? () => setState(() => _agency = a) : null,
                ),
              ],
            ],
          ),
          FieldRequestType.escalation => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('Propose a level'),
                      style: context.type.label.copyWith(color: pal.textSoft),
                    ),
                  ),
                  Text(
                    t('Now: {currentLevel}', {
                      'currentLevel': widget.currentLevel,
                    }),
                    style: context.type.detail.copyWith(color: pal.label),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in kAlarmLevels.skip(above + 1))
                    PickChip(
                      label: l,
                      selected: _level == l,
                      onTap: editable
                          ? () => setState(() => _level = l)
                          : () {},
                    ),
                ],
              ),
            ],
          ),
        },
        if (widget.type != FieldRequestType.escalation) ...[
          const SizedBox(height: 14),
          _UrgencyChips(
            value: _urgency,
            onChanged: editable ? (u) => setState(() => _urgency = u) : null,
          ),
        ],
        if (missing != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(AppIcons.error, size: 16, color: pal.live),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    missing,
                    style: context.type.detail.copyWith(color: pal.live),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(AppIcons.send, size: 16, color: pal.onBackground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.recipient,
                style: context.type.detail.copyWith(color: pal.label),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          InlineAlert(body: _error!, tone: AlertTone.danger),
        ],
        const SizedBox(height: 16),
        AppButton(send, run: true, busy: _sending, onPressed: _send),
        const SizedBox(height: 10),
        AppButton.secondary(
          t('Cancel'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String helper,
    required String hint,
    required bool multiline,
    required bool editable,
  }) {
    final pal = context.pal;
    return LabeledField(
      label: label,
      builder: (focus) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            focusNode: focus,
            enabled: editable,
            minLines: multiline ? 4 : 1,
            maxLines: multiline ? 8 : 1,
            textInputAction: multiline
                ? TextInputAction.newline
                : TextInputAction.done,
            style: context.type.input,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 8),
          Text(helper, style: context.type.detail.copyWith(color: pal.label)),
        ],
      ),
    );
  }
}

/// Opens [RequestSheet] over the scrim; completes with the request once
/// [onSend] has, or null when the sheet is put away.
Future<FieldRequest?> showRequestSheet(
  BuildContext context, {
  required FieldRequestType type,
  required String eyebrow,
  required String recipient,
  required Future<void> Function(FieldRequest request) onSend,
  String currentLevel = '1st Alarm',
}) => showFrameSheet<FieldRequest>(
  context,
  builder: (_) => RequestSheet(
    type: type,
    eyebrow: eyebrow,
    recipient: recipient,
    onSend: onSend,
    currentLevel: currentLevel,
  ),
);

/// The mandatory fire classification on arrival (04 · Fire type sheet; PRD
/// v13 §4.5.3): the type first, then the subtype for Structural, Electrical
/// and Vehicular; Rubbish, Grass and Chemical confirm directly. Pops with the
/// [FireClassification] picked — sending it is the caller's.
class FireTypeSheet extends StatefulWidget {
  const FireTypeSheet({super.key, required this.areaLabel, this.arrivedAt});

  /// "Area 1.2".
  final String areaLabel;

  /// "9:49 PM".
  final String? arrivedAt;

  @override
  State<FireTypeSheet> createState() => _FireTypeSheetState();
}

class _FireTypeSheetState extends State<FireTypeSheet> {
  FireType? _type;
  String? _subtype;
  bool _subtypeStep = false;

  static const _glyphs = {
    FireType.structural: AppIcons.apartment,
    FireType.electrical: AppIcons.localFireDepartment,
    FireType.vehicular: AppIcons.fireTruck,
    FireType.rubbish: AppIcons.delete,
    FireType.grass: AppIcons.waves,
    FireType.chemical: AppIcons.warning,
  };

  void _continue() {
    final type = _type;
    if (type == null) return;
    if (type.hasSubtypes && !_subtypeStep) {
      setState(() => _subtypeStep = true);
      return;
    }
    if (type.hasSubtypes && _subtype == null) return;
    Navigator.of(context).pop(FireClassification(type, _subtype));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final type = _type;
    if (_subtypeStep && type != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _subtypeStep = false);
        },
        child: _PassSixSheet(
          children: [
            _SheetHead(
              eyebrow: t('{areaLabel} — {label} · step 2 of 2', {
                'areaLabel': widget.areaLabel,
                'label': type.label,
              }),
              title: t('{label} — which kind?', {'label': type.label}),
              body: t(
                'Pick the closest match. The Captain can correct it in '
                'the post-incident report.',
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, s) in type.subtypes.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              ChoiceRow(
                title: s,
                selected: _subtype == s,
                onTap: () => setState(() => _subtype = s),
              ),
            ],
            const SizedBox(height: 14),
            AppButton(
              _subtype == null
                  ? t('Pick one to confirm')
                  : t('Confirm {label} — {_subtype}', {
                      'label': type.label,
                      '_subtype': _subtype,
                    }),
              run: true,
              onPressed: _subtype == null ? null : _continue,
            ),
          ],
        ),
      );
    }

    final arrived = widget.arrivedAt == null
        ? ''
        : t(' — arrived {arrivedAt}', {'arrivedAt': widget.arrivedAt});
    return _PassSixSheet(
      children: [
        _SheetHead(
          eyebrow: t('{areaLabel}{arrived} · required', {
            'areaLabel': widget.areaLabel,
            'arrived': arrived,
          }),
          title: t('What’s burning?'),
          body: t(
            'Pick the fire type. Requests for water, equipment, backup '
            'and escalation unlock once it is set.',
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, type) in FireType.values.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          ChoiceRow(
            title: type.label,
            meta: type.hasSubtypes ? type.subtypes.join(' · ') : null,
            icon: _glyphs[type],
            tint: pal.accent,
            selected: _type == type,
            onTap: () => setState(() {
              if (_type != type) _subtype = null;
              _type = type;
            }),
          ),
        ],
        const SizedBox(height: 14),
        AppButton(
          type == null || type.hasSubtypes
              ? t('Continue')
              : t('Confirm {label}', {'label': type.label}),
          run: true,
          onPressed: type == null ? null : _continue,
        ),
      ],
    );
  }
}

/// Opens [FireTypeSheet]; completes with the classification, or null when the
/// sheet is put away without one.
Future<FireClassification?> showFireTypeSheet(
  BuildContext context, {
  required String areaLabel,
  String? arrivedAt,
}) => showFrameSheet<FireClassification>(
  context,
  builder: (_) => FireTypeSheet(areaLabel: areaLabel, arrivedAt: arrivedAt),
);
