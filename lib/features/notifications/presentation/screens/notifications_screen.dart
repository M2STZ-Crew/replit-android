import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reports/presentation/screens/sos_screen.dart';
import '../../data/notification_api.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';

/// The alert inbox, and where a neighbour answers the 300 m crowdsourced
/// notification with Report or Ignore (Section 2.2).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationApiProvider).markAllRead();
              ref
                ..invalidate(notificationsProvider)
                ..invalidate(unreadCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(notificationsProvider)
            ..invalidate(unreadCountProvider);
        },
        child: switch (items) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => _Message(
              icon: Icons.cloud_off,
              text: error.toString(),
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          AsyncValue(:final value?) when value.isEmpty => const _Message(
              icon: Icons.notifications_none,
              text: 'No alerts yet.\n\n'
                  'If a fire is reported within 300 m of you, an alert appears '
                  'here so you can confirm or dismiss it.',
            ),
          AsyncValue(:final value?) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NotificationCard(item: value[i]),
            ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SosScreen()),
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
        : DateFormat('d MMM, h:mm a').format(item.createdAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isRead ? Colors.black12 : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isNeighborhoodAlert
                    ? Icons.local_fire_department
                    : Icons.notifications_outlined,
                color: item.isNeighborhoodAlert
                    ? AppColors.primary
                    : Colors.black45,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(when, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          if (item.isNeighborhoodAlert) ...[
            const SizedBox(height: 12),
            if (answered != null)
              Row(
                children: [
                  Icon(
                    answered == NeighborhoodResponse.report
                        ? Icons.check_circle
                        : Icons.do_not_disturb_on,
                    size: 18,
                    color: answered == NeighborhoodResponse.report
                        ? AppColors.success
                        : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    answered == NeighborhoodResponse.report
                        ? 'You confirmed this fire'
                        : "Dismissed — you won't be alerted about this area again",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _answer(NeighborhoodResponse.report),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Report'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _answer(NeighborhoodResponse.ignore),
                      child: const Text('Ignore'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Must scroll, or pull-to-refresh stops working on the empty state.
    return ListView(
      padding: const EdgeInsets.all(36),
      children: [
        const SizedBox(height: 70),
        Icon(icon, size: 52, color: Colors.black26),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}
