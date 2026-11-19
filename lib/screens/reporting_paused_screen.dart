import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/reporting_standing.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import '../widgets/loading.dart';
import '../widgets/no_emoji.dart';

/// Reporting paused (v1.12.52; backend v1.12.41).
///
/// 19 Nov 2026: "a false alarm or prank report can be temporarily cannot
/// report and has a progressive penalty". Shown instead of the camera while a
/// resident's reporting is paused or removed, and from a strike's alert: when
/// they can report again and why, that 911 and fire alerts still work, how
/// strikes add up, and their appeal. Never who gave the strike.
class ReportingPausedScreen extends StatefulWidget {
  const ReportingPausedScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<ReportingPausedScreen> createState() => _ReportingPausedScreenState();
}

class _ReportingPausedScreenState extends State<ReportingPausedScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  ReportingStanding? _standing = ReportingStanding.cached;
  bool _loading = true;
  bool _lessonShown = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final standing = await ReportingStanding.refresh(_api);
    if (!mounted) return;
    setState(() {
      _standing = standing;
      _loading = false;
    });
    final due = standing?.lessonDue;
    if (due != null && !_lessonShown) {
      _lessonShown = true;
      await showStrikeLesson(context, api: _api, strikeId: due);
    }
  }

  Future<void> _call911() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '911'));
    } catch (_) {
      // No dialler: the number is on the screen.
    }
  }

  Future<void> _appeal(StrikeView strike) async {
    final sent = await showFrameSheet<bool>(
      context,
      builder: (_) => StrikeAppealSheet(api: _api, strike: strike),
    );
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Appeal sent. You will get the answer in RepLiT.')),
      ),
    );
    await _load();
  }

  String _title(ReportingStanding? s) {
    if (s == null) return t('Reporting');
    if (s.removed) return t('Reporting removed');
    if (s.blocksNow) return t('Reporting paused');
    return t('You can send reports');
  }

  @override
  Widget build(BuildContext context) {
    final standing = _standing;
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: t('Reporting'),
              title: _title(standing),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: standing == null && _loading
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: _content(standing),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(ReportingStanding? s) {
    final pal = context.pal;
    const gap = SizedBox(height: 16);
    final latest = s?.latest;
    return [
      if (s == null)
        InlineAlert(
          tone: AlertTone.warning,
          body: t(
            'Could not check right now. In an emergency, call 911.',
          ),
        )
      else
        Panel(
          radius: AppRadius.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_headline(s), style: context.type.rowTitleLg),
              const SizedBox(height: 6),
              Text(_explain(s), style: context.type.body),
            ],
          ),
        ),
      gap,
      // 911 is never blocked, at any step.
      Panel(
        key: const ValueKey('call-911'),
        radius: AppRadius.card,
        color: pal.live.withValues(alpha: 0.10),
        border: pal.live.withValues(alpha: 0.4),
        onTap: _call911,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(AppIcons.phoneInTalk, color: pal.live),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Emergency now? Call 911'),
                    style: context.type.rowTitleLg,
                  ),
                  Text(
                    t('You still get fire alerts.'),
                    style: context.type.bodySm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (latest != null) ...[
        const SizedBox(height: 24),
        SectionHeader(t('Why')),
        const SizedBox(height: 8),
        _strikeCard(latest),
        ..._appealPart(latest),
      ],
      const SizedBox(height: 24),
      SectionHeader(t('How strikes work')),
      const SizedBox(height: 8),
      for (final step in const [1, 2, 3, 4])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            strikeStepText(step),
            style: context.type.body.copyWith(
              fontWeight: s != null && s.step == step ? FontWeight.w700 : null,
            ),
          ),
        ),
      const SizedBox(height: 6),
      Text(
        t(
          'Only a report staff find was a prank counts, never an honest '
          'mistake. A strike ends 12 months after it is given.',
        ),
        style: context.type.bodySm,
      ),
      const SizedBox(height: 12),
      TextLink(
        t('What a false alarm costs'),
        onTap: () => showStrikeLesson(context, api: _api),
      ),
      if (s != null && s.strikes.length > 1) ...[
        const SizedBox(height: 24),
        SectionHeader(t('Earlier strikes')),
        const SizedBox(height: 8),
        for (final strike in s.strikes.skip(1))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${strikeStepText(strike.step)} · ${untilText(strike.givenAt)}'
              '${strike.removed ? ' · ${t('removed')}' : ''}',
              style: context.type.bodySm,
            ),
          ),
      ],
    ];
  }

  String _headline(ReportingStanding s) {
    if (s.removed) return t('You can no longer send reports');
    final until = s.pausedUntil;
    if (s.blocksNow && until != null) {
      return t('You can send reports again on {when}', {
        'when': untilText(until),
      });
    }
    return t('You can send reports');
  }

  String _explain(ReportingStanding s) {
    if (s.removed) {
      return t(
        'After repeated prank reports, reporting was removed from your '
        'account. You may appeal below.',
      );
    }
    if (s.blocksNow) {
      final latest = s.latest;
      if (latest != null && latest.awaitingCheck) {
        return t(
          'Staff found another of your reports was a prank. A second staff '
          'member will check it; until then, reporting is paused.',
        );
      }
      return t('Staff found that a report you sent was a prank.');
    }
    final checks = s.verifyFirstUntil;
    if (checks != null && checks.isAfter(DateTime.now())) {
      return t(
        'Until {when}, staff check your reports before your neighbours are '
        'alerted.',
        {'when': untilText(checks)},
      );
    }
    return t('Nothing is stopping your reports.');
  }

  Widget _strikeCard(StrikeView strike) {
    final status = switch (strike) {
      _ when strike.removed => t('Removed'),
      _ when strike.awaitingCheck => t('Waiting for a second staff check'),
      _ => t('In effect'),
    };
    return Panel(
      key: const ValueKey('latest-strike'),
      radius: AppRadius.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${strike.reason}”', style: context.type.body),
          const SizedBox(height: 8),
          Text(
            '${strikeStepText(strike.step)} · ${untilText(strike.givenAt)}',
            style: context.type.bodySm,
          ),
          const SizedBox(height: 4),
          Text(status, style: context.type.caption),
        ],
      ),
    );
  }

  List<Widget> _appealPart(StrikeView strike) {
    const gap = SizedBox(height: 12);
    switch (strike.appealState) {
      case 'pending':
        return [
          gap,
          InlineAlert(
            title: t('Your appeal is waiting for an answer'),
            body: strike.appealText ?? '',
          ),
        ];
      case 'upheld':
        return [
          gap,
          InlineAlert(
            tone: AlertTone.warning,
            title: t('Appeal not accepted'),
            body: strike.appealNote ?? t('The strike stays.'),
          ),
          if (strike.canAppeal) ...[gap, _appealButton(strike)],
        ];
      case 'overturned':
        return [
          gap,
          InlineAlert(
            tone: AlertTone.success,
            title: t('Appeal accepted'),
            body: strike.appealNote ?? t('The strike was removed.'),
          ),
        ];
      default:
        return strike.canAppeal ? [gap, _appealButton(strike)] : const [];
    }
  }

  Widget _appealButton(StrikeView strike) => AppButton.secondary(
    t('Appeal this strike'),
    onPressed: () => _appeal(strike),
  );
}

/// The lesson, once per strike (or any time from the paused screen): what a
/// false alarm costs, and what to do in an emergency.
Future<void> showStrikeLesson(
  BuildContext context, {
  required ApiClient api,
  String? strikeId,
}) async {
  await showFrameSheet<void>(context, builder: (_) => const StrikeLessonSheet());
  if (strikeId == null) return;
  try {
    await api.strikeLessonSeen(strikeId);
  } catch (_) {
    // Shown again next time; nothing else depends on it.
  }
}

/// At start-up: the lesson, when a new strike's is due.
Future<void> showStrikeLessonIfDue(BuildContext context, ApiClient api) async {
  final standing = await ReportingStanding.refresh(api);
  final due = standing?.lessonDue;
  if (due == null || !context.mounted) return;
  await showStrikeLesson(context, api: api, strikeId: due);
}

class StrikeLessonSheet extends StatelessWidget {
  const StrikeLessonSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final points = [
      t(
        'A fire truck and its crew go to the wrong place, and a real fire '
        'waits for them.',
      ),
      t('Your neighbours get an alert and worry for nothing.'),
      t(
        'Giving a false or malicious fire alarm is against the Fire Code (RA '
        '9514, Sec. 8(i)). BFP can fine up to ₱50,000.',
      ),
      t(
        'Each prank report pauses your reporting for longer: 24 hours, then 7 '
        'days, then 30 days, then no more reporting.',
      ),
    ];
    return SheetFrame(
      children: [
        SheetTitles(
          eyebrow: t('Before you report again'),
          title: t('What a false alarm costs'),
          body: t('An honest mistake never counts. In an emergency, call 911.'),
        ),
        const SizedBox(height: 16),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    AppIcons.warning,
                    size: 18,
                    color: context.pal.warn,
                  ),
                ),
                Expanded(child: Text(point, style: context.type.body)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        AppButton(
          t('I understand'),
          run: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The resident's appeal: why this was not a prank. Decided by staff other
/// than whoever gave the strike.
class StrikeAppealSheet extends StatefulWidget {
  const StrikeAppealSheet({super.key, required this.api, required this.strike});

  final ApiClient api;
  final StrikeView strike;

  @override
  State<StrikeAppealSheet> createState() => _StrikeAppealSheetState();
}

class _StrikeAppealSheetState extends State<StrikeAppealSheet> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.appealStrike(widget.strike.id, _text.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = t('Could not send. Check your connection.'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _text.text.trim().length >= 10;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: strikeStepText(widget.strike.step),
            title: t('Appeal this strike'),
            body: t(
              'Say why this was not a prank, for example what you saw. Staff '
              'who did not give the strike decide, and you get the answer in '
              'RepLiT.',
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: t('Your appeal'),
            builder: (focus) => TextField(
              key: const ValueKey('appeal-text'),
              inputFormatters: const [NoEmojiFormatter()],
              controller: _text,
              focusNode: focus,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: context.type.input,
              decoration: InputDecoration(
                hintText: t('I saw smoke from my neighbour burning leaves.'),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: context.type.bodySm.copyWith(color: context.pal.live),
            ),
          ],
          const SizedBox(height: 8),
          AppButton(
            t('Send appeal'),
            run: true,
            busy: _sending,
            onPressed: ready && !_sending ? _send : null,
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
