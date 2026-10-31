import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/notification_router.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/app_icons.dart';

/// Opens what an Alerts row is about; [NotificationRouter] unless a test
/// gives its own.
typedef NotificationOpener =
    Future<bool> Function(
      NavigatorState nav,
      Map<String, dynamic> notification,
    );

/// In-app notification inbox — the history behind the bell.
///
/// Role-scoped server-side: citizens only ever receive fire alerts plus their
/// own incident updates; staff get new fires and alarm types too.
///
/// v1.12.6: a row opens what it is about — the incident, "Do you see it
/// too?", the live tracker, the alarm queue — the same place the push would
/// have opened. Rows with somewhere to go carry a chevron.
///
/// The hand-off does not cover this screen, so it is aligned to it: coral for
/// anything unread, glass for everything already seen, and the same uppercase
/// headings as the rest of the app.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.api,
    this.opener,
    this.asTab = false,
  });

  final ApiClient? api;
  final NotificationOpener? opener;

  /// A tab on a bottom bar (the responder's Alerts): nothing sits under it,
  /// so it has no Back.
  final bool asTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

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

  static Map<String, dynamic> _data(Map<String, dynamic> n) =>
      (n['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  Future<bool> _route(NavigatorState nav, Map<String, dynamic> n) =>
      NotificationRouter(
        api: _api,
      ).open(nav, type: n['type'] as String?, data: _data(n));

  Future<void> _tap(Map<String, dynamic> n) async {
    final nav = Navigator.of(context);
    if (n['is_read'] != true) {
      try {
        await _api.markNotificationRead(n['id'] as String);
      } catch (_) {
        // Still open it; it is marked read next time.
      }
      if (mounted) setState(() => n['is_read'] = true);
    }
    if (!canOpen(n['type'] as String?, _data(n))) return;
    final opened = await (widget.opener ?? _route)(nav, n);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is nothing to open for this one.')),
      );
    }
  }

  /// type → (label, icon, colour)
  (String, IconData, Color) _meta(String type) => switch (type) {
    // A new fire, for staff (v1.12.6).
    'incident_new' => (
      'New fire',
      AppIcons.localFireDepartment,
      context.pal.live,
    ),
    'fire_alert' => (
      'Fire alert',
      AppIcons.localFireDepartment,
      context.pal.live,
    ),
    'incident_update' => (
      'Incident update',
      AppIcons.campaign,
      context.pal.accent,
    ),
    'responder_dispatch' => (
      'Dispatched unit',
      AppIcons.localShipping,
      context.pal.accent,
    ),
    // Admin routed an incident to this team captain's team (v10 §2.6.2).
    'incident_routed' => (
      'Routed to your team',
      AppIcons.altRoute,
      context.pal.ok,
    ),
    'alarm_request' => (
      'Alarm request',
      AppIcons.notificationsActive,
      context.pal.live,
    ),
    'alarm_executed' => ('Alarm raised', AppIcons.campaign, context.pal.ok),
    // BFP's answer to the coordinator or responder who asked.
    'alarm_request_answered' => (
      'BFP answered',
      AppIcons.campaign,
      context.pal.accent,
    ),
    'national_id_reviewed' => (
      'National ID',
      AppIcons.badge,
      context.pal.accent,
    ),
    _ => ('Notification', AppIcons.notifications, context.pal.info),
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
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: ScreenHeader(
                eyebrow: unread == 0 ? 'Nothing unread' : '$unread unread',
                title: 'Alerts',
                showBack: !widget.asTab,
                trailing: unread == 0
                    ? null
                    : GestureDetector(
                        onTap: _markAllRead,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Eyebrow(
                            'Mark all read',
                            color: context.pal.accent,
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
        icon: AppIcons.cloudOff,
        tone: context.pal.live,
        title: 'Could not load alerts',
        body: _error!,
        action: AppButton.secondary('Try again', onPressed: _load),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: AppIcons.notifications,
        title: 'No alerts yet',
        body:
            'If something is reported near you, an alert appears here so you '
            'can confirm or dismiss it.',
      );
    }
    return RefreshIndicator(
      color: context.pal.accent,
      backgroundColor: context.pal.surfaceSolid,
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
      color: unread ? color.withValues(alpha: 0.08) : context.pal.glassDim,
      border: unread ? color.withValues(alpha: 0.35) : context.pal.line,
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
                      style: context.type.cardTitle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ago(n['created_at'] as String?),
                    style: context.type.meta,
                  ),
                  if (unread) ...[
                    const SizedBox(height: 8),
                    LiveDot(color: color, size: 7),
                  ],
                ],
              ),
              if (canOpen(n['type'] as String?, _data(n))) ...[
                const SizedBox(width: 6),
                Icon(
                  AppIcons.chevronRight,
                  key: const ValueKey('opens'),
                  color: context.pal.muted,
                ),
              ],
            ],
          ),
          const SizedBox(height: 13),
          Text(
            (n['body'] as String?) ?? '',
            style: context.type.meta.copyWith(
              fontSize: 12,
              height: 17 / 12,
              color: context.pal.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}
