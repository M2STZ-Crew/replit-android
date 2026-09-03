import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/report.dart';
import '../providers/my_reports_provider.dart';

/// "My reports" — the General User's view of what happened to what they sent
/// (Section 2.6: submit reports, view status).
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myReportsProvider),
        child: switch (reports) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => _Retry(
              message: error.toString(),
              onRetry: () => ref.invalidate(myReportsProvider),
            ),
          AsyncValue(:final value?) when value.isEmpty => const _Empty(),
          AsyncValue(:final value?) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ReportCard(report: value[i]),
            ),
          _ => const _Empty(),
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final when = report.createdAt == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(report.createdAt!.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.photoUrl != null)
            CachedNetworkImage(
              imageUrl: report.photoUrl!,
              height: 150,
              fit: BoxFit.cover,
              // Signed URLs expire; a broken image must not look like a lost report.
              errorWidget: (_, _, _) => Container(
                height: 150,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text('Photo unavailable'),
              ),
              placeholder: (_, _) => Container(
                height: 150,
                color: Colors.black12,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(report: report),
                    const Spacer(),
                    Text(when, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.areaDesignation ?? 'Awaiting grouping',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  report.agenciesLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (report.gpsDiscrepancyFlag) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Being double-checked by a dispatcher',
                          style: Theme.of(context).textTheme.bodySmall,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.report});

  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.areaStatus == null
        ? Colors.grey
        : AppColors.forStatus(report.areaStatus!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        report.statusLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    // Inside a RefreshIndicator the child must always scroll, or pull-to-refresh
    // stops working on the empty state.
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.inbox_outlined, size: 56, color: Colors.black26),
        const SizedBox(height: 16),
        Text(
          "You haven't sent any reports yet",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Reports you send will appear here with their progress.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off, size: 48, color: Colors.black26),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
