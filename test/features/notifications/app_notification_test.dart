import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/notifications/data/models/app_notification.dart';

Map<String, dynamic> _json({required dynamic data}) => {
  'id': 1,
  'channel': 'in_app',
  'type': 'purchase.recorded',
  'title': 'Purchase recorded',
  'body': 'Your purchase was recorded.',
  'data': data,
  'status': 'delivered',
  'sent_at': '2026-08-21T09:30:23+00:00',
  'read_at': null,
  'created_at': '2026-08-21T09:30:23+00:00',
};

void main() {
  group('AppNotification.fromJson', () {
    // A genuine Phase 9 bug, reproduced against the real backend: PHP
    // serializes an empty associative array as a JSON `[]`, not `{}`.
    // `NotificationFactory`'s own default payload uses `'data' => []`, so
    // this shape is not a fixture artifact -- any notification created via
    // that default (or any real payload that happens to carry no extra
    // data) hit this. The old `json['data'] as Map?` cast threw
    // (`List` is neither `Map` nor `null`), which surfaced as "Something
    // unexpected happened" on the real Notifications screen.
    test(
      'parses an empty JSON array for data as an empty map, not a crash',
      () {
        final notification = AppNotification.fromJson(_json(data: <dynamic>[]));

        expect(notification.data, isEmpty);
      },
    );

    test('parses a real populated data object correctly', () {
      final notification = AppNotification.fromJson(
        _json(data: {'redemption_id': 20}),
      );

      expect(notification.data, {'redemption_id': 20});
    });

    test('parses a null data field as an empty map', () {
      final notification = AppNotification.fromJson(_json(data: null));

      expect(notification.data, isEmpty);
    });
  });
}
