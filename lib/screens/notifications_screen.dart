import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';

/// In-app notification inbox — the history behind the bell.
///
/// Role-scoped server-side: citizens only ever receive fire alerts plus their
/// own incident updates; staff get dispatch and alarm types too.
///
/// The hand-off does not cover this screen, so it is aligned to it: coral for
/// anything unread, glass for everything already seen, and the same uppercase
/// headings as the rest of the app.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _api.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not load notifications.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    await _api.markAllNotificationsRead();
    if (mounted) {
      setState(() {
        _items = [
          for (final n in _items) {...n, 'is_read': true},
        ];
      });
    }
  }

  Future<void> _tap(Map<String, dynamic> n) async {
    if (n['is_read'] != true) {
      await _api.markNotificationRead(n['id'] as String);
      if (mounted) setState(() => n['is_read'] = true);
    }
  }

  /// type → (label, icon, colour)
  (String, IconData, Color) _meta(String type) => switch (type) {
    'fire_alert' => (
      'Fire alert',
      Icons.local_fire_department,
      AppColors.live,
    ),
    'incident_update' => (
      'Incident update',
      Icons.campaign_outlined,
      AppColors.accent,
    ),
    'responder_dispatch' => (
      'Dispatched unit',
      Icons.local_shipping_outlined,
      AppColors.accent,
    ),
    'alarm_request' => (
      'Alarm request',
      Icons.notifications_active_outlined,
      AppColors.live,
    ),
    'alarm_executed' => ('Alarm raised', Icons.campaign, AppColors.ok),
    _ => ('Notification', Icons.notifications_outlined, AppColors.info),
  };

  String _ago(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: ScreenHeader(
                eyebrow: unread == 0 ? 'Nothing unread' : '$unread unread',
                title: 'Alerts',
                trailing: unread == 0
                    ? null
                    : GestureDetector(
                        onTap: _markAllRead,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Eyebrow(
                            'Mark all read',
                            color: AppColors.accent,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: AppColors.live,
        title: 'Could not load alerts',
        body: _error!,
        action: AppButton.secondary('Try again', onPressed: _load),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No alerts yet',
        body: 'If something is reported near you, an alert appears here so you '
            'can confirm or dismiss it.',
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surfaceSolid,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _tile(_items[i]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final (label, icon, color) = _meta((n['type'] as String?) ?? '');
    final unread = n['is_read'] != true;

    return Panel(
      onTap: () => _tap(n),
      color: unread ? color.withValues(alpha: 0.08) : AppColors.glassDim,
      border: unread ? color.withValues(alpha: 0.35) : AppColors.line,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(tint: color, icon: icon, size: 36, glyph: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(label, color: color),
                    const SizedBox(height: 6),
                    Text(
                      ((n['title'] as String?) ?? '').toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_ago(n['created_at'] as String?), style: AppText.meta),
                  if (unread) ...[
                    const SizedBox(height: 8),
                    LiveDot(color: color, size: 7),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            (n['body'] as String?) ?? '',
            style: AppText.meta.copyWith(
              fontSize: 12,
              height: 17 / 12,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}
