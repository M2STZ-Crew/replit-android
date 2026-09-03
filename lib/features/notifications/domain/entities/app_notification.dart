/// One row from the in-app inbox (NotificationItem).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.data = const {},
    this.createdAt,
  });

  final String id;

  /// public.notification_type — 'fire_alert' is the 300 m neighbourhood alert.
  final String type;

  final String title;
  final String body;
  final bool isRead;

  /// Free-form payload. For a neighbourhood alert it carries `area_id`, which is
  /// what the Report/Ignore answer has to reference.
  final Map<String, dynamic> data;

  final DateTime? createdAt;

  /// True when this is a crowdsourced neighbourhood alert the user can answer.
  ///
  /// Requires an area_id: without one there is nothing to respond about, and
  /// showing the buttons would produce a request the server rejects.
  bool get isNeighborhoodAlert =>
      type == 'fire_alert' && (data['area_id'] as String?)?.isNotEmpty == true;

  String? get areaId => data['area_id'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isRead: map['is_read'] as bool? ?? false,
      data: switch (map['data']) {
        final Map<String, dynamic> d => d,
        final Map d => d.map((k, v) => MapEntry(k.toString(), v)),
        _ => const {},
      },
      createdAt: switch (map['created_at']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}
