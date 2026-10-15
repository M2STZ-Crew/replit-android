import 'package:flutter/material.dart';

import '../location/place_names.dart';
import '../models/area_view.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'design.dart';

/// The REPLIT (MAIN) 04 components the Coordinator Experience (06) is built
/// from and the rest of the app had not needed yet: the tab and detail screen
/// headers, the counted segment, the inline alert, the Area card, the
/// confidence meter, the lifecycle rail, the summary card, the list item, the
/// radio, the sheet frame and the action bar.
///
/// Measurements are the design's; colours and type come from the palette, so
/// the light theme follows.

/// The plate behind a leading icon that is not an agency's: color/surface/
/// subtle, a step off the card it sits on.
Color _subtle(BuildContext context) =>
    context.pal.isLight ? context.pal.hover : const Color(0xFF1A1A1A);

/// Screen header, Tab type: the eyebrow (whose screen this is — the team, the
/// account) over a Heading 3 title, with an optional light subtitle.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Eyebrow(eyebrow!, color: context.pal.accentInk),
                  const SizedBox(height: 4),
                ],
                Semantics(
                  header: true,
                  child: Text(title.toUpperCase(), style: context.type.title),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: context.type.body.copyWith(
                      color: context.pal.textSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Screen header, Detail type: Back, then the eyebrow (the Area and where it
/// is), a Heading 1 title (uppercase, two lines at most) and an address line
/// that wraps to two.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BackWell(onTap: onBack),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          if (eyebrow != null) ...[
            Eyebrow(eyebrow!, color: context.pal.accentInk),
            const SizedBox(height: 4),
          ],
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.heading1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.body.copyWith(color: context.pal.textSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one eyebrow that labels a section, with an optional count or scope on
/// the right. Content starts 12px below it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Expanded(child: Eyebrow(title, color: context.pal.accentInk)),
          if (meta != null) ...[
            const SizedBox(width: 12),
            Eyebrow(meta!, color: context.pal.label),
          ],
        ],
      ),
    );
  }
}

/// What a segment's count means: coral needs you, red is under way, green is
/// settled.
enum SegmentTone { attention, live, settled }

/// One tab of the counted segmented control (the Coordinator queue). The
/// count is the headline, coloured by its meaning; the selected segment gets
/// the chip treatment — coral tint and a 1.5px coral edge.
class CountSegment extends StatelessWidget {
  const CountSegment({
    super.key,
    required this.count,
    required this.label,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String label;
  final SegmentTone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final countColour = switch (tone) {
      SegmentTone.attention => pal.accentInk,
      SegmentTone.live => pal.live,
      SegmentTone.settled => pal.ok,
    };
    final shape = BorderRadius.circular(AppRadius.card);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$count $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          highlightColor: pal.pressed,
          splashColor: pal.pressed,
          child: AnimatedContainer(
            duration: Motion.of(context).state,
            curve: Motion.standard,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: context.type.numeral.copyWith(
                    height: 28 / 26,
                    letterSpacing: -1,
                    color: countColour,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(
                    color: selected ? pal.accentInk : pal.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Info explains a rule; Warning flags a known limit; Danger states what
/// failed and what happens next; Success confirms.
enum AlertTone { info, warning, danger, success }

/// A message that stays in the screen (Inline alert, Solid). Icon and words,
/// never colour alone. Info sits on the card surface; the other tones on
/// their own tint with an edge in the tone.
class InlineAlert extends StatelessWidget {
  const InlineAlert({
    super.key,
    required this.body,
    this.tone = AlertTone.info,
    this.title,
    this.action,
    this.onAction,
  });

  final String body;
  final AlertTone tone;
  final String? title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (colour, icon) = switch (tone) {
      AlertTone.info => (pal.info, AppIcons.info),
      AlertTone.warning => (pal.warn, AppIcons.warning),
      AlertTone.danger => (pal.live, AppIcons.error),
      AlertTone.success => (pal.ok, AppIcons.checkCircle),
    };
    final tinted = tone != AlertTone.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tinted
            ? Color.alphaBlend(colour.withValues(alpha: 0.14), pal.background)
            : pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tinted ? colour : pal.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: colour)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: context.type.rowTitleLg),
                  const SizedBox(height: 4),
                ],
                Text(
                  body,
                  style: context.type.bodySm.copyWith(color: pal.textSoft),
                ),
                if (action != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextLink(action!, onTap: onAction!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The agency's icon on its plate (40px, radius sm). Fire covers Fire
/// Volunteer and BFP; the words beside it say which.
class AgencyPlate extends StatelessWidget {
  const AgencyPlate({
    super.key,
    this.agency = 'fire_volunteer',
    this.size = 40,
  });

  final String agency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (tint, icon) = switch (agency) {
      'police' => (pal.police, AppIcons.localPolice),
      'medical' => (pal.medical, AppIcons.medicalServices),
      'barangay' => (pal.barangay, AppIcons.accountBalance),
      _ => (pal.accent, AppIcons.localFireDepartment),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pal.wellFor(tint),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size / 2, color: pal.glyphOn(tint)),
      ),
    );
  }
}

/// A 40px icon on a plate, for rows that are not an agency's. Untinted, it
/// sits on the subtle surface; tinted, on the tone's wash with the glyph in
/// the tone.
class IconPlate extends StatelessWidget {
  const IconPlate(this.icon, {super.key, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: t == null ? _subtle(context) : context.pal.statusTint(t),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: t ?? context.pal.textSoft),
      ),
    );
  }
}

/// How an Area card asks for attention: Attention needs this person's
/// decision (coral edge); Live is under way (red tint and edge).
enum AreaEmphasis { normal, attention, live }

/// One incident Area — the unit of work (Area card). The status sits on its
/// own row so the title and address get the full width; the facts are
/// labelled, not a middle-dot string; the "Accepted" line is staff-only. The
/// whole card opens the Area; the button is the shortcut to the decision.
class AreaCard extends StatelessWidget {
  const AreaCard({
    super.key,
    required this.status,
    required this.title,
    required this.place,
    this.agency = 'fire_volunteer',
    this.facts = const [],
    this.note,
    this.action,
    this.onTap,
    this.emphasis = AreaEmphasis.normal,
  });

  final String status;
  final String title;
  final String place;
  final String agency;

  /// (label, value) pairs: Reports, Confidence, Reported.
  final List<(String, String)> facts;

  /// The staff-only line under the facts: who accepted, who arrived.
  final String? note;

  /// The button's words: Decide, Open, File report.
  final String? action;
  final VoidCallback? onTap;
  final AreaEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.card);
    final (fill, edge, width) = switch (emphasis) {
      AreaEmphasis.attention => (pal.surface, pal.accent, 1.5),
      AreaEmphasis.live => (
        Color.alphaBlend(pal.live.withValues(alpha: 0.12), pal.surface),
        pal.live,
        1.5,
      ),
      AreaEmphasis.normal => (pal.surface, pal.line, 1.0),
    };
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        highlightColor: pal.pressed,
        splashColor: pal.pressed,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: shape,
            border: Border.all(color: edge, width: width),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LifecycleChip(status),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AgencyPlate(agency: agency),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.listTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.bodySm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, (label, value)) in facts.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _Fact(label, value)),
                      ],
                    ],
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: ExcludeSemantics(
                          child: Icon(
                            AppIcons.group,
                            size: 16,
                            color: pal.label,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note!,
                          style: context.type.bodySm.copyWith(
                            color: pal.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  AppButton.secondary(action!, onPressed: onTap),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.pal.background,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.type.caption.copyWith(color: context.pal.label),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.type.rowValue.copyWith(
              color: context.pal.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports join an Area only from within this distance of its centre
/// (clustering, Master Context §3.4).
const double kAreaRadiusMetres = 300;

/// Area confidence (§4.3): 0.4·N + 0.3·S + 0.3·V, banded. Three segments
/// filled to the band, the band word and the score — the bar is never the
/// only signal — and the three terms with their real values, so a
/// coordinator can see why a score is low.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({super.key, required this.area});

  /// An IncidentDetail: confidence_band/score and n/s/v_score.
  final AreaView area;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final raw = area.raw;
    final s = (raw['s_score'] as num?)?.toDouble() ?? 0;
    final v = (raw['v_score'] as num?)?.toDouble() ?? 0;
    final reports = area.reports;
    final filled = switch (area.band) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
    final spread = reports < 2
        ? 'One report, no spread yet'
        : s <= 0
        ? 'Spread over 300 m'
        : 'Spread ${((1 - s) * kAreaRadiusMetres).round()} m';
    final value = context.type.rowValue.copyWith(color: pal.onBackground);
    Widget row(String label, String figure) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.type.bodySm.copyWith(color: pal.label),
            ),
          ),
          const SizedBox(width: 12),
          // The figure keeps its width and sits at the right edge; the label
          // wraps first.
          Text(figure, textAlign: TextAlign.right, style: value),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Confidence',
                style: context.type.label.copyWith(color: pal.textSoft),
              ),
            ),
            Text(
              '${area.bandWord} — ${area.score.toStringAsFixed(2)}',
              style: value,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < filled ? pal.accent : pal.lineStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        row(
          'Corroboration (×0.4)',
          reports >= 10
              ? '$reports reports, full weight'
              : '$reports of 10 reports',
        ),
        row('Spatial agreement (×0.3)', spread),
        row(
          'Source credibility (×0.3)',
          'Reporters average ${(v * 100).round()}%',
        ),
      ],
    );
  }
}

/// The six named steps of an Area's life (§4.5). Done and current fill
/// coral; the current step's name is repeated at top right and in bold
/// below, so position and colour are never the only cue. The report still
/// owed after the fire sits inside Fire out.
class LifecycleRail extends StatelessWidget {
  const LifecycleRail({super.key, required this.status});

  final String status;

  static const steps = [
    'Reported',
    'Verified',
    'En route',
    'Arrived',
    'Fire out',
    'Closed',
  ];

  static int indexOf(String status) => switch (status) {
    'reported' => 0,
    'verified' => 1,
    'en_route' => 2,
    'arrived' => 3,
    'fire_out' || 'post_incident_report' => 4,
    'closed' => 5,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final at = indexOf(status);
    return Semantics(
      label: 'Progress: ${steps[at]}, step ${at + 1} of ${steps.length}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow('Progress', color: pal.label)),
              Text(steps[at].toUpperCase(), style: context.type.subtitle),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= at ? pal.accent : pal.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Text(
                    steps[i],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: i == at
                        ? context.type.labelSm.copyWith(color: pal.onBackground)
                        : context.type.caption.copyWith(color: pal.label),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Area summary (§4.8): plain operator text. A missing summary points to
/// the report list, so it never blocks a decision.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, this.text, this.meta, this.writing = false});

  /// The summary, or null when there is none.
  final String? text;

  /// When it was written.
  final String? meta;

  /// The server is writing it now.
  final bool writing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final ready = text != null && text!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow('Summary', color: pal.accentInk)),
              if (meta != null)
                Text(
                  meta!,
                  style: context.type.detail.copyWith(color: pal.label),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ready
                ? text!.trim()
                : writing
                ? 'Lit is writing the summary. The reports below are the full '
                      'record until it is ready.'
                : 'No summary yet. The reports below are the full record.',
            style: context.type.body.copyWith(
              color: ready ? pal.textSoft : pal.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row on a card (List item). The whole row is the target, at
/// least 56px tall. Leading takes an [IconPlate] or [AgencyPlate]; trailing a
/// chevron (opens detail), a value, or a switch.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.edge,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  /// A coloured edge in place of the hairline, for a row that is the point
  /// of its screen.
  final Color? edge;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.card);
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        highlightColor: pal.pressed,
        splashColor: pal.pressed,
        child: Ink(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: shape,
            border: Border.all(
              color: edge ?? pal.line,
              width: edge == null ? 1 : 1.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.listTitle,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: context.type.bodySm),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                  if (chevron) ...[
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Icon(
                        AppIcons.chevronRight,
                        size: 20,
                        color: pal.label,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A fact at the end of a [ListRow]: tabular, in the given tone.
class RowValue extends StatelessWidget {
  const RowValue(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.type.rowValue.copyWith(
      color: color ?? context.pal.textSoft,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// One choice of a radio group: a 22px ring and a 13px label in a 44px row.
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.of(context).state,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: pal.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? pal.accent : pal.lineStrong,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pal.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: context.type.rowTitleLg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet's frame: the surface, the grabber, 24px sides, and the
/// home-indicator clearance below.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: context.pal.line)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: SheetHandle(margin: EdgeInsets.zero)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A sheet's titles: the eyebrow (what it is about), the question, and what
/// saying yes does.
class SheetTitles extends StatelessWidget {
  const SheetTitles({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.eyebrowColour,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color? eyebrowColour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow, color: eyebrowColour ?? context.pal.accentInk),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(title, style: context.type.sheetTitle),
        ),
        const SizedBox(height: 8),
        Text(body, style: context.type.bodyLarge),
      ],
    );
  }
}

/// Opens [SheetFrame] content as a bottom sheet over the scrim.
Future<T?> showFrameSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showAppSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: builder,
);

/// The sticky bar on decision and run screens that have no nav bar: the one
/// primary action, an optional secondary under it, above the home
/// indicator.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.pal.background,
        border: Border(top: BorderSide(color: context.pal.line)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
}

/// Builds with an Area's place in words once the geocoder answers, and with
/// the degrees until then (or for good, when it knows nothing).
class AreaPlace extends StatelessWidget {
  const AreaPlace({super.key, required this.area, required this.builder});

  final AreaView area;
  final Widget Function(BuildContext context, PlaceName place) builder;

  @override
  Widget build(BuildContext context) {
    final c = area.centre;
    if (c == null) return builder(context, PlaceName.none);
    return FutureBuilder<PlaceName>(
      future: PlaceNames.of(c.latitude, c.longitude),
      builder: (context, snap) => builder(context, snap.data ?? PlaceName.none),
    );
  }
}

/// "F. Victor Street, Barangay 76", or the degrees when the place is unknown.
String placeLine(AreaView area, PlaceName place) {
  final c = area.centre;
  return place.line ??
      (c == null ? 'Location unknown' : degrees(c.latitude, c.longitude));
}
