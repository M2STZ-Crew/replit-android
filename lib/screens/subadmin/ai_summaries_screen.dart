import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart';

/// Opens a link outside the app — the phone's browser, which saves the PDF to
/// Downloads. A parameter so tests need no browser.
typedef LinkOpener = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A day as the coordinator wrote it on the incident: "10/5/2026", in
/// Philippine time (UTC+8 all year) whatever the phone is set to.
String summaryDate(String? iso) {
  if (iso == null) return '';
  final at = DateTime.tryParse(iso);
  if (at == null) return '';
  final ph = at.toUtc().add(const Duration(hours: 8));
  return '${ph.month}/${ph.day}/${ph.year}';
}

/// "4:40 PM", Philippine time.
String summaryTime(String? iso) {
  if (iso == null) return '';
  final at = DateTime.tryParse(iso);
  if (at == null) return '';
  final ph = at.toUtc().add(const Duration(hours: 8));
  final h = ph.hour % 12 == 0 ? 12 : ph.hour % 12;
  return '$h:${ph.minute.toString().padLeft(2, '0')} ${ph.hour < 12 ? 'AM' : 'PM'}';
}

/// "Summarized incident — 10/5/2026": the day the summary was written, or,
/// while the first one is being written, the day the last team filed.
String summaryTitle(Map<String, dynamic> item) =>
    'Summarized incident — '
    '${summaryDate((item['generated_at'] ?? item['last_filed_at']) as String?)}';

/// "Area 3 · Hercules Fire Brigade, BFP Pasay".
String summarySubtitle(Map<String, dynamic> item) {
  final teams = ((item['teams'] as List?) ?? const []).cast<String>();
  final filed = (item['reports_filed'] as num?)?.toInt() ?? teams.length;
  final who = teams.isNotEmpty
      ? teams.join(', ')
      : '$filed ${filed == 1 ? 'team' : 'teams'}';
  return '${item['designation'] ?? 'Incident'} · $who';
}

/// The coordinator's AI summaries (v1.12.5).
///
/// Each incident a team has filed its Post-Incident Report for, newest first.
/// The AI writes the summary when a report is filed — nobody asks for one —
/// and rewrites it when another team files, so it always covers every report.
/// A summary still being written shows as such and the list checks back on
/// its own. Tapping one opens it as a note, with the PDF to download: the PDF
/// is built when it is downloaded, never stored, so it is never out of date.
class AiSummariesScreen extends StatefulWidget {
  const AiSummariesScreen({super.key, this.me, this.api, this.openLink});

  final Map<String, dynamic>? me;
  final ApiClient? api;
  final LinkOpener? openLink;

  @override
  State<AiSummariesScreen> createState() => _AiSummariesScreenState();
}

class _AiSummariesScreenState extends State<AiSummariesScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  /// While a summary is being written the list looks again on its own, a few
  /// times — a summary takes seconds, and a coordinator should not have to
  /// keep pulling to see it arrive.
  Timer? _recheck;
  int _rechecks = 0;
  static const _recheckEvery = Duration(seconds: 10);
  static const _maxRechecks = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recheck?.cancel();
    super.dispose();
  }

  Future<void> _refresh() {
    _rechecks = 0;
    return _load();
  }

  Future<void> _load() async {
    _recheck?.cancel();
    try {
      final raw = await _api.getAiSummaries();
      if (!mounted) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
      if (_items.any((i) => i['state'] == 'writing') &&
          _rechecks < _maxRechecks) {
        _rechecks++;
        _recheck = Timer(_recheckEvery, _load);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the summaries. Check your connection.';
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SummaryNoteScreen(
          item: item,
          me: widget.me,
          api: _api,
          openLink: widget.openLink,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return StaffScaffold(
      me: widget.me,
      page: StaffPage.summaries,
      home: true,
      title: 'AI summaries',
      body: RefreshIndicator(
        color: context.pal.accent,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              'The AI writes a summary of each incident from the teams\' '
              'Post-Incident Reports as soon as one is filed, and rewrites it '
              'when another team files. Open one to read it or download the '
              'report as a PDF.',
              style: context.type.bodySm,
            ),
            const SizedBox(height: 22),
            ..._list(),
          ],
        ),
      ),
    );
  }

  List<Widget> _list() {
    if (_loading) {
      return [
        const SizedBox(height: 40),
        Center(child: CircularProgressIndicator(color: context.pal.accent)),
      ];
    }
    if (_error != null) {
      return [
        Text(
          _error!,
          style: context.type.caption.copyWith(color: context.pal.live),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'No summaries yet',
          body:
              'A summary appears here once a team files its Post-Incident '
              'Report for an incident.',
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: Eyebrow('Summarized incidents', color: context.pal.accent),
          ),
          Eyebrow('${_items.length}', color: context.pal.muted),
        ],
      ),
      const SizedBox(height: 12),
      for (final item in _items) ...[
        _SummaryRow(item: item, onTap: () => _open(item)),
        const SizedBox(height: 8),
      ],
    ];
  }
}

/// One incident: "Summarized incident — 10/5/2026", where, and who filed.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = item['state'] as String?;
    final hasText = item['summary_text'] != null;
    return Panel(
      radius: AppRadius.card,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconWell(
            tint: hasText ? context.pal.info : context.pal.muted,
            icon: Icons.auto_awesome_outlined,
            size: 36,
            glyph: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summaryTitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.rowTitleLg,
                ),
                const SizedBox(height: 4),
                Text(
                  summarySubtitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (state == 'writing')
            Tag(
              hasText ? 'Updating' : 'Writing',
              color: context.pal.info,
              dot: true,
            )
          else if (state == 'unavailable')
            Tag('No summary', color: context.pal.muted),
          Icon(Icons.chevron_right_rounded, color: context.pal.muted),
        ],
      ),
    );
  }
}

/// One summary, read as a note, with the PDF to download.
class SummaryNoteScreen extends StatefulWidget {
  const SummaryNoteScreen({
    super.key,
    required this.item,
    this.me,
    this.api,
    this.openLink,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? me;
  final ApiClient? api;
  final LinkOpener? openLink;

  @override
  State<SummaryNoteScreen> createState() => _SummaryNoteScreenState();
}

class _SummaryNoteScreenState extends State<SummaryNoteScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  bool _downloading = false;

  Map<String, dynamic> get _item => widget.item;

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Ask for a five-minute link, then hand it to the browser, which saves the
  /// PDF to Downloads.
  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final link = await _api.getReportLink('${_item['area_id']}');
      final opened = await (widget.openLink ?? _openInBrowser)(link);
      if (!opened) _toast('Could not open the browser to download the PDF.');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = (_item['summary_text'] as String?)?.trim();
    final state = _item['state'] as String?;
    final model = _item['model'] as String?;
    final written = _item['generated_at'] as String?;
    return StaffScaffold(
      me: widget.me,
      page: StaffPage.summaries,
      title: 'AI summary',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: AppButton(
            'Download PDF',
            icon: Icons.download_rounded,
            busy: _downloading,
            onPressed: _downloading ? null : _download,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Text(summaryTitle(_item), style: context.type.cardTitle),
          const SizedBox(height: 6),
          Text(summarySubtitle(_item), style: context.type.caption),
          const SizedBox(height: 18),
          if (state == 'writing')
            _Notice(
              text == null
                  ? 'The AI is writing this summary now. It is usually ready '
                        'within a minute — go back and the list will show it.'
                  : 'Another team filed its report after this was written. The '
                        'AI is rewriting the summary to include it.',
            )
          else if (state == 'unavailable')
            const _Notice(
              'No summary has been written: the server has no AI key yet. '
              'The PDF still has every team\'s report.',
              icon: Icons.info_outline_rounded,
            ),
          if (state != 'ready' && state != null) const SizedBox(height: 14),
          if (text != null && text.isNotEmpty) ...[
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: SelectableText(
                text,
                key: const ValueKey('summary-text'),
                style: context.type.body.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Written by AI${model == null ? '' : ' ($model)'}'
              '${written == null ? '' : ' on ${summaryDate(written)} at ${summaryTime(written)}'}'
              ' from the teams\' reports. Check it against them before relying '
              'on it.',
              style: context.type.captionSm,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'The PDF has the incident, its timeline, every team\'s '
            'Post-Incident Report and this summary. It is made when you '
            'download it, so it includes every report filed by then.',
            style: context.type.caption,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.icon = Icons.hourglass_top_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      border: context.pal.info.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.pal.info),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.type.bodySm)),
        ],
      ),
    );
  }
}
