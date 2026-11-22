import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/alarm.dart';
import '../models/alarm_status.dart';
import '../models/area_view.dart' show clockText;
import '../theme.dart';
import 'app_icons.dart';
import 'motion.dart';

/// How a status is drawn: colour, icon and words, never colour alone.
({Color fill, Color edge, Color ink, Color glyph, IconData icon}) _look(
  AppPalette pal,
  AlarmStatus status,
) {
  Color wash(Color tone) =>
      Color.alphaBlend(tone.withValues(alpha: 0.16), pal.background);
  if (status.raised) {
    const red = AppColors.markerRisk;
    return (
      fill: red,
      edge: red,
      ink: Colors.white,
      glyph: Colors.white,
      icon: AppIcons.campaign,
    );
  }
  final (tone, icon) = switch (status.situation) {
    FireSituation.fireOut => (pal.ok, AppIcons.checkCircle),
    FireSituation.underControl => (pal.info, AppIcons.shield),
    FireSituation.burning when status.level != null => (
      pal.warn,
      AppIcons.campaign,
    ),
    FireSituation.burning => (pal.label, AppIcons.hourglassTop),
  };
  return (
    fill: wash(tone),
    edge: tone,
    ink: pal.onBackground,
    glyph: tone,
    icon: icon,
  );
}

/// The status in a few words: "3rd alarm", "Under control", "Fire out". The
/// levels keep BFP's words in both languages, as said on the radio.
String alarmStatusWord(AlarmStatus status) => switch (status.situation) {
  FireSituation.fireOut => t('Fire out'),
  FireSituation.underControl => t('Under control'),
  FireSituation.burning =>
    status.level == null ? t('No alarm yet') : alarmWord(status.level),
};

/// "9:42 PM", or "21 Nov, 9:42 PM" on another day.
String _time(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (at.year == today.year && at.month == today.month && at.day == today.day) {
    return clockText(at);
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${at.day} ${months[at.month - 1]}, ${clockText(at)}';
}

/// When, and by whom: the person too, for staff.
String? alarmStatusDetail(AlarmStatus status, {required bool staff}) {
  String? who(String? org, String? name) {
    final parts = [?org, if (staff) ?name];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  final was = status.level == null
      ? null
      : t('Was {level}', {'level': alarmWord(status.level)});
  switch (status.situation) {
    case FireSituation.fireOut:
      final at = status.fireOutAt;
      final line = [?was, if (at != null) _time(at)].join(' · ');
      return line.isEmpty ? null : line;
    case FireSituation.underControl:
      return [
        ?was,
        _time(status.underControlAt!),
        ?who(status.underControlByOrg, status.underControlByName),
      ].join(' · ');
    case FireSituation.burning:
      final at = status.setAt;
      if (status.level == null || at == null) return null;
      final time = _time(at);
      final by = who(status.setByOrg, status.setByName);
      if (status.raised) {
        return by == null
            ? t('Raised {time}', {'time': time})
            : t('Raised {time} by {who}', {'time': time, 'who': by});
      }
      return by == null
          ? t('Set {time}', {'time': time})
          : t('Set {time} by {who}', {'time': time, 'who': by});
  }
}

/// What it means, for someone who is not in the fire service.
String alarmStatusMeaning(AlarmStatus status) => switch (status.situation) {
  FireSituation.fireOut => t('The fire is out.'),
  FireSituation.underControl => t(
    'It is no longer spreading. Stay away until the fire is out.',
  ),
  FireSituation.burning when status.highest => t(
    'The highest alarm. Stay far away and keep the roads clear.',
  ),
  FireSituation.burning when status.raised => t(
    'It needs more firefighters and trucks. Stay away and keep the roads clear.',
  ),
  FireSituation.burning when status.level != null => t(
    'A confirmed fire. Stay away from it and keep the roads clear.',
  ),
  FireSituation.burning => t(
    'An alarm is set once responders confirm the fire.',
  ),
};

/// The highlighted alarm status at the top of every detail screen (v1.12.60;
/// 22 Nov 2026: "highlight it in the details because it is crucial";
/// answered "Everyone, everywhere"). Raised alarms are solid red. A change is
/// read out to screen readers.
///
/// Draws nothing for a rejected or merged incident and, with [showNone] off,
/// before there is a level; [spacing] goes under it only when it draws.
class AlarmStatusBanner extends StatelessWidget {
  const AlarmStatusBanner(
    this.status, {
    super.key,
    this.staff = false,
    this.compact = false,
    this.showNone = true,
    this.spacing = 16,
    this.action,
    this.onAction,
  });

  final AlarmStatus status;

  /// Staff read who set it; residents what it means.
  final bool staff;

  /// The word and one line, where there is little room.
  final bool compact;
  final bool showNone;
  final double spacing;

  /// "Withdraw", for who declared it may take it back.
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (!status.applies || (!showNone && !status.known)) {
      return const SizedBox.shrink();
    }
    final look = _look(context.pal, status);
    final detail = alarmStatusDetail(status, staff: staff);
    final meaning = staff && status.known ? null : alarmStatusMeaning(status);
    // Compact: one line at most, and none before there is a level.
    final lines = !compact
        ? [?detail, ?meaning]
        : status.known
        ? [?(meaning ?? detail)]
        : const <String>[];
    final soft = status.raised ? Colors.white : context.pal.textSoft;
    final act = action;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: AnimatedContainer(
          duration: Motion.of(context).state,
          curve: Motion.standard,
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: look.fill,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: look.edge, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: compact ? 32 : 40,
                  height: compact ? 32 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: look.glyph.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    look.icon,
                    size: compact ? 18 : 22,
                    color: look.glyph,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact || lines.isEmpty) ...[
                      Text(
                        t('Alarm status').toUpperCase(),
                        style: context.type.tag.copyWith(color: soft),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      alarmStatusWord(status).toUpperCase(),
                      style: context.type.rowTitleLg.copyWith(
                        color: look.ink,
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: 3),
                      Text(
                        line,
                        style: context.type.bodySm.copyWith(color: soft),
                      ),
                    ],
                    if (act != null && onAction != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: look.ink,
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          act,
                          style: context.type.bodySm.copyWith(
                            color: look.ink,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: look.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small badge on lists and map cards; nothing before there is a level.
class AlarmBadge extends StatelessWidget {
  const AlarmBadge(this.status, {super.key});

  final AlarmStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.known) return const SizedBox.shrink();
    final look = _look(context.pal, status);
    final word = alarmStatusWord(status);
    return Semantics(
      label: '${t('Alarm status')}: $word',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: look.fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: look.edge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(look.icon, size: 12, color: look.glyph),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                word.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.tag.copyWith(color: look.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
