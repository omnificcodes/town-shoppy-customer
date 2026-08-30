/// Mirrors `App\Domain\Notification\Http\Resources\NotificationResource`.
///
/// `type` is one of the 17 `NotificationType` enum values from the backend
/// (e.g. `purchase.recorded`, `redemption.completed`) — see
/// `NotificationIcons` for how each maps to an icon/label. No type beyond
/// those 17 is ever invented client-side.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.channel,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.status,
    required this.sentAt,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      channel: json['channel'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      // The backend serializes an empty PHP associative array as a JSON
      // `[]`, not `{}` -- a bare `as Map?` cast throws on that (a List is
      // neither a Map nor null), so this checks the real runtime type
      // first, matching the same defensive pattern already used for every
      // other optional nested object in this codebase (see Merchant,
      // Redemption, Purchase, AssociationRef, ReferralSummary).
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      status: json['status'] as String,
      sentAt: _parseDate(json['sent_at']),
      readAt: _parseDate(json['read_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  final int id;
  final String channel;
  final String type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String status;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    channel: channel,
    type: type,
    title: title,
    body: body,
    data: data,
    status: 'read',
    sentAt: sentAt,
    readAt: at,
    createdAt: createdAt,
  );

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
