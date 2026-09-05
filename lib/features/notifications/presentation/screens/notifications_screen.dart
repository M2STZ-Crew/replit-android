import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../../reports/presentation/screens/sos_screen.dart';
import '../../data/notification_api.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';

/// The alert inbox, and where a neighbour answers the 300 m crowdsourced
/// notification with Report or Ignore (Section 2.2).
///
/// The hand-off does not cover this screen, so it is aligned to it: coral for
/// the live neighbourhood alert, glass for everything already read, and the
/// same uppercase headings.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: ScreenHeader(
                eyebrow: unread == 0
                    ? 'Nothing unread'
                    : '$unread unread',
                title: 'Alerts',
                trailing: unread == 0
                    ? null
                    : GestureDetector(
                        onTap: () async {
                          await ref.read(notificationApiProvider).markAllRead();
                          ref
                            ..invalidate(notificationsProvider)
                            ..invalidate(unreadCountProvider);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Eyebrow('Mark all read',
                              color: AppColors.accent),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surfaceSolid,
                onRefresh: () async {
                  ref
                    ..invalidate(notificationsProvider)
                    ..invalidate(unreadCountProvider);
                },
                child: switch (items) {
                  AsyncLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  AsyncError(:final error) => _Scroll(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      tone: AppColors.live,
                      title: 'Could not load alerts',
                      body: error.toString(),
                      action: AppButton.secondary(
                        'Try again',
                        onPressed: () =>
                            ref.invalidate(notificationsProvider),
                      ),
                    ),
                  ),
                  AsyncValue(:final value?) when value.isEmpty => const _Scroll(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No alerts yet',
                      body: 'If something is reported within '
                          '${AppConstants.areaRadiusMeters} m of you, an alert '
                          'appears here so you can confirm or dismiss it.',
                    ),
                  ),
                  AsyncValue(:final value?) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    itemCount: value.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _NotificationCard(item: value[i]),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});

  final Widget child;

  @override
  // Must scroll, or pull-to-refresh stops working on the empty state.
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    children: [const SizedBox(height: 40), child],
  );
}

class _NotificationCard extends ConsumerStatefulWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  bool _busy = false;
  String? _error;

  Future<void> _answer(String response) async {
    final item = widget.item;
    final areaId = item.areaId;
    if (areaId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await ref.read(alertResponsesProvider.notifier).respond(
      notificationId: item.id,
      areaId: areaId,
      response: response,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });

    // [Report] means "yes, there is a fire here" — send them to the SOS flow so
    // the corroboration becomes an actual report with its own photo and GPS
    // (Section 2.2: the button redirects to the Alert Page).
    if (failure == null && response == NeighborhoodResponse.report && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SosScreen()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final answered = ref
        .watch(alertResponsesProvider.notifier)
        .responseFor(item.areaId);
    final when = item.createdAt == null
        ? ''
        : DateFormat('d MMM · h:mm a').format(item.createdAt!.toLocal());
    final live = item.isNeighborhoodAlert && !item.isRead;

    return Panel(
      color: live ? AppColors.accent.withValues(alpha: 0.08)
          : AppColors.surfaceDim,
      border: live ? AppColors.accent.withValues(alpha: 0.35) : AppColors.line,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                tint: item.isNeighborhoodAlert
                    ? AppColors.accent
                    : AppColors.muted,
                size: 34,
                glyph: 17,
                asset: item.isNeighborhoodAlert ? Art.incident : null,
                icon: item.isNeighborhoodAlert
                    ? null
                    : Icons.notifications_none_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title.toUpperCase(),
                      style: AppText.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(when, style: AppText.meta),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                const LiveDot(color: AppColors.accent, size: 7),
              ],
            ],
          ),
          const SizedBox(height: 13),
          Text(
            item.body,
            style: AppText.meta.copyWith(
              fontSize: 12,
              height: 17 / 12,
              color: AppColors.textSoft,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.meta.copyWith(fontSize: 12, color: AppColors.live),
            ),
          ],

          if (item.isNeighborhoodAlert) ...[
            const SizedBox(height: 16),
            if (answered != null)
              Row(
                children: [
                  Icon(
                    answered == NeighborhoodResponse.report
                        ? Icons.check_circle_rounded
                        : Icons.do_not_disturb_on_outlined,
                    size: 17,
                    color: answered == NeighborhoodResponse.report
                        ? AppColors.ok
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      answered == NeighborhoodResponse.report
                          ? 'You confirmed this — thank you.'
                          : "Dismissed. You won't be alerted about this area "
                              'again.',
                      style: AppText.meta.copyWith(height: 15 / 11),
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                'Do you see it too? Confirming raises how fast responders are '
                'sent.',
                style: AppText.meta.copyWith(height: 15 / 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      'Yes, I see it',
                      height: 46,
                      busy: _busy,
                      onPressed: _busy
                          ? null
                          : () => _answer(NeighborhoodResponse.report),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton.secondary(
                      'Ignore',
                      height: 46,
                      onPressed: _busy
                          ? null
                          : () => _answer(NeighborhoodResponse.ignore),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
