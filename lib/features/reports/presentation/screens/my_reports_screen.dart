import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../domain/entities/report.dart';
import '../providers/my_reports_provider.dart';

/// "Your reports" — the incident-history screen from the hand-off.
///
/// The design's three stat tiles were Sent / Resolved / Avg arrival. The first
/// two are countable from the reports themselves; arrival time is not, because
/// GET /reports/mine carries no dispatch timestamps. It is replaced with the
/// count still open, which is the number the reporter actually wants: "is
/// anyone still coming?"
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surfaceSolid,
          onRefresh: () async => ref.invalidate(myReportsProvider),
          child: switch (reports) {
            AsyncLoading() => const _Scrollable(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            AsyncError(:final error) => _Scrollable(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                tone: AppColors.live,
                title: 'Could not load your reports',
                body: error.toString(),
                action: AppButton.secondary(
                  'Try again',
                  onPressed: () => ref.invalidate(myReportsProvider),
                ),
              ),
            ),
            AsyncValue(:final value?) => _History(reports: value),
            _ => const _Scrollable(child: SizedBox.shrink()),
          },
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    // Inside a RefreshIndicator the child must always scroll, or pull-to-refresh
    // stops working on the empty and error states.
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
    children: [const ScreenHeader(title: 'Your reports'), child],
  );
}

class _History extends StatelessWidget {
  const _History({required this.reports});

  final List<MyReport> reports;

  @override
  Widget build(BuildContext context) {
    final resolved = reports
        .where((r) => r.areaStatus == IncidentStatus.resolved)
        .length;
    final open = reports.where((r) => r.isActive).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        const ScreenHeader(title: 'Your reports'),
        const SizedBox(height: 26),

        Row(
          children: [
            Expanded(
              child: StatTile(value: '${reports.length}', label: 'Sent'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: '$resolved',
                label: 'Resolved',
                color: AppColors.ok,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: '$open',
                label: 'Still open',
                color: open > 0 ? AppColors.accent : AppColors.text,
              ),
            ),
          ],
        ),

        if (reports.isEmpty) ...[
          const SizedBox(height: 40),
          const EmptyState(
            title: "Nothing sent yet",
            body: 'Reports you send appear here with what came of them — who '
                'responded, and when it was closed.',
          ),
        ] else ...[
          const SizedBox(height: 28),
          const Eyebrow('Everything you have sent', color: AppColors.accent),
          const SizedBox(height: 12),
          for (final report in reports) ...[
            _ReportCard(report: report),
            const SizedBox(height: 10),
          ],
        ],

        const SizedBox(height: 12),
        Panel(
          radius: AppRadius.control,
          color: AppColors.surfaceDim,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your reports stay on the barangay record. Photos are held '
                  'in private storage and only responders can open them.',
                  style: AppText.meta.copyWith(height: 16 / 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final live = report.isActive;
    final color = report.areaStatus == null
        ? AppColors.muted
        : AppColors.forStatus(report.areaStatus!);
    final when = report.createdAt == null
        ? 'Just now'
        : DateFormat('d MMM · h:mm a').format(report.createdAt!.toLocal());

    return Panel(
      color: live ? color.withValues(alpha: 0.08) : AppColors.surfaceDim,
      border: live ? color.withValues(alpha: 0.35) : AppColors.line,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.panel - 1),
              ),
              child: CachedNetworkImage(
                imageUrl: report.photoUrl!,
                height: 140,
                fit: BoxFit.cover,
                // Signed URLs expire; a broken image must not read as a lost
                // report.
                errorWidget: (_, _, _) => Container(
                  height: 140,
                  color: AppColors.canvas,
                  alignment: Alignment.center,
                  child: Text(
                    'PHOTO LINK EXPIRED',
                    style: AppText.tag.copyWith(color: AppColors.faint),
                  ),
                ),
                placeholder: (_, _) =>
                    Container(height: 140, color: AppColors.canvas),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconWell(
                      tint: color,
                      asset: Art.incident,
                      size: 34,
                      glyph: 17,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (report.areaDesignation ?? 'Awaiting grouping')
                                .toUpperCase(),
                            style: AppText.cardTitle,
                          ),
                          const SizedBox(height: 5),
                          Text(when, style: AppText.meta),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tag(
                      report.statusLabel,
                      color: color,
                      dot: live && report.areaStatus != null,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Divider(color: color.withValues(alpha: live ? 0.2 : 0.12)),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.agenciesLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                          color: live ? AppColors.label : AppColors.muted,
                        ),
                      ),
                    ),
                    if (report.areaConfidenceBand != null)
                      Text(
                        '${report.areaConfidenceBand!.toUpperCase()} CONFIDENCE',
                        style: AppText.tag.copyWith(
                          color: switch (report.areaConfidenceBand) {
                            'high' => AppColors.ok,
                            'medium' => AppColors.statusPending,
                            _ => AppColors.muted,
                          },
                        ),
                      ),
                  ],
                ),
                if (report.gpsDiscrepancyFlag) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.statusPending),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Being double-checked — the photo and your phone '
                          'disagreed on the location.',
                          style: AppText.meta.copyWith(height: 15 / 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
