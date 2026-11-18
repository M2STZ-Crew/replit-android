import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/area_view.dart';
import '../theme.dart';
import 'coordinator_kit.dart';
import 'design.dart';
import '../i18n/i18n.dart';
import 'no_emoji.dart';

/// What [AlarmAskSheet] decided: a level to ask BFP for, with why — or, with
/// no level, take the waiting request back.
class AlarmAsk {
  const AlarmAsk(this.level, [this.why]) : openRequests = false;

  /// BFP: open the Area's waiting requests instead.
  const AlarmAsk.requests() : level = null, why = null, openRequests = true;

  final String? level;
  final String? why;
  final bool openRequests;
}

/// Ask BFP to raise an Area's alarm (PRD v14 §4.5.3: Fire Volunteer
/// requests, BFP executes), from LIVE or a Fire Volunteer responder's
/// incident screen.
///
/// Offers only the levels above the Area's now, the only ones the server
/// accepts. While a request of theirs waits it says so and lets them take it
/// back; asking for another level replaces it on the server.
class AlarmAskSheet extends StatefulWidget {
  const AlarmAskSheet({
    super.key,
    required this.area,
    this.waiting,
    this.bfp = false,
    this.requestsWaiting = 0,
  });

  final AreaView area;

  /// BFP raises the level itself (v1.12.49, 18 Nov 2026: "bfp coordinator
  /// can raise an alarm without the request of fv"); Fire Volunteers ask.
  final bool bfp;

  /// BFP: Fire Volunteer requests for this Area waiting on an answer.
  final int requestsWaiting;

  /// The asker's request for this Area that BFP has not answered yet.
  final AlarmRequest? waiting;

  @override
  State<AlarmAskSheet> createState() => _AlarmAskSheetState();
}

class _AlarmAskSheetState extends State<AlarmAskSheet> {
  final TextEditingController _why = TextEditingController();
  String? _level;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  void _send(String level) {
    final why = _why.text.trim();
    Navigator.of(context).pop(AlarmAsk(level, why.isEmpty ? null : why));
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final waiting = widget.waiting;
    final asked = waiting?.askedAt;
    final levels = levelsAbove(area.alarmLevel);
    final level = _level;
    // The sheet rides above the keyboard while the reason is typed.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: '${area.name} · now at ${alarmWord(area.alarmLevel)}',
            title: widget.bfp
                ? t('Raise the alarm?')
                : 'Ask BFP to raise the alarm?',
            body: widget.bfp
                ? t(
                    'Only BFP sets the alarm level. Everyone on this fire sees '
                    'the new level at once, and Fire Volunteer requests it '
                    'meets are answered with it.',
                  )
                : 'BFP sets the alarm level. Your request reaches every BFP '
                      'Coordinator at once with this Area attached, and you '
                      'are told when they answer.',
          ),
          if (widget.bfp && widget.requestsWaiting > 0) ...[
            const SizedBox(height: 16),
            InlineAlert(
              tone: AlertTone.warning,
              title: widget.requestsWaiting == 1
                  ? t('1 request waiting')
                  : t('{n} requests waiting', {'n': widget.requestsWaiting}),
              body: t('Fire Volunteers asked for a higher level.'),
              action: t('See requests'),
              onAction: () =>
                  Navigator.of(context).pop(const AlarmAsk.requests()),
            ),
          ],
          if (waiting != null) ...[
            const SizedBox(height: 16),
            InlineAlert(
              tone: AlertTone.warning,
              title: 'Waiting for BFP',
              body:
                  'You asked for ${alarmWord(waiting.level)}'
                  '${asked == null ? '' : ' ${agoText(asked)}'}. Ask for '
                  'another level to replace it.',
              action: 'Take it back',
              onAction: () => Navigator.of(context).pop(const AlarmAsk(null)),
            ),
          ],
          const SizedBox(height: 16),
          if (levels.isEmpty)
            InlineAlert(
              body: '${area.name} is at General alarm, the highest level.',
            )
          else ...[
            for (final l in levels)
              RadioRow(
                label: l == waiting?.level
                    ? '${alarmWord(l)} · asked'
                    : alarmWord(l),
                selected: l == level,
                onTap: () => setState(() => _level = l),
              ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Why (optional)',
              builder: (focus) => TextField(
                inputFormatters: const [NoEmojiFormatter()],
                controller: _why,
                focusNode: focus,
                // The server keeps 1000 characters of BFP's note.
                maxLength: widget.bfp ? 1000 : 2000,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: context.type.input,
                decoration: const InputDecoration(
                  hintText: 'Spreading to the next house',
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              level == null
                  ? 'Choose a level'
                  : widget.bfp
                  ? t('Raise to {alarmWord}', {'alarmWord': alarmWord(level)})
                  : 'Ask for ${alarmWord(level)}',
              run: true,
              onPressed: level == null ? null : () => _send(level),
            ),
          ],
          const SizedBox(height: 10),
          AppButton.secondary(
            'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
