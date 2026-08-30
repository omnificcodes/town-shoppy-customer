import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/notifications/application/notifications_controller.dart';
import 'package:customer/features/notifications/data/models/app_notification.dart';
import 'package:customer/features/notifications/presentation/notifications_screen.dart';

import '../../helpers/responsive_test_helper.dart';

class _StubController extends NotificationsController {
  @override
  Future<NotificationsListState> build() async {
    return NotificationsListState(
      items: [
        AppNotification(
          id: 1,
          channel: 'in_app',
          type: 'redemption.completed',
          title: 'Your redemption at The Grand Downtown Corner Cafe and Bakery Emporium was completed',
          body:
              'Your Town Coin redemption for ₹999,999.99 at The Grand Downtown Corner Cafe, Bakery, and '
              'Artisanal Coffee Roastery Emporium (Main Street Flagship Location) has been verified and '
              'settled successfully by the merchant.',
          data: const {},
          status: 'delivered',
          sentAt: DateTime(2026, 1, 1),
          readAt: null,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      nextCursor: null,
    );
  }
}

Widget _wrap() {
  return ProviderScope(
    overrides: [notificationsControllerProvider.overrideWith(_StubController.new)],
    child: MaterialApp(theme: AppTheme.light, home: const NotificationsScreen()),
  );
}

void main() {
  testWidgets('NotificationsScreen renders a long title/body without overflow at every mandated viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.textContaining('Your redemption at'), findsOneWidget);
        expect(find.byTooltip('Mark all read'), findsOneWidget);
      },
    );
  });
}
