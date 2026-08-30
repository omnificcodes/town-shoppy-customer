import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/notifications/data/models/app_notification.dart';
import 'package:customer/features/notifications/presentation/notification_tile.dart';

AppNotification _notification({required DateTime? readAt}) {
  return AppNotification(
    id: 1,
    channel: 'in_app',
    type: 'purchase.recorded',
    title: 'Purchase recorded',
    body: 'Your purchase was recorded.',
    data: const {},
    status: 'delivered',
    sentAt: DateTime(2026, 1, 1),
    readAt: readAt,
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('NotificationTile', () {
    // A Phase 10 finding: the visual unread signals (tint/bold/dot) are all
    // decorative and invisible to a screen reader -- without an explicit
    // accessible label, an unread notification and a read one announced
    // identically. Confirmed via a real semantics-tree dump before the fix.
    testWidgets('an unread notification is announced as "Unread" to assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(NotificationTile(notification: _notification(readAt: null), onTap: () {})));

      final semantics = tester.getSemantics(find.byType(NotificationTile));
      expect(semantics.label, startsWith('Unread, Purchase recorded'));

      handle.dispose();
    });

    testWidgets('a read notification is not announced as unread', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(NotificationTile(notification: _notification(readAt: DateTime(2026, 1, 1)), onTap: () {})));

      final semantics = tester.getSemantics(find.byType(NotificationTile));
      expect(semantics.label, isNot(contains('Unread')));
      expect(semantics.label, startsWith('Purchase recorded'));

      handle.dispose();
    });
  });
}
