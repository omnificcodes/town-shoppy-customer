import 'package:customer/core/app_mode/app_mode.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/notifications/application/notifications_controller.dart';
import 'package:customer/features/notifications/data/models/app_notification.dart';
import 'package:customer/features/notifications/presentation/notification_navigation.dart';
import 'package:customer/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('notificationTarget', () {
    test('customer-facing types stay in Customer mode', () {
      for (final type in ['purchase.recorded', 'purchase.rejected', 'redemption.completed', 'referral.qualified', 'offer_redemption.approved', 'draw.won', 'wallet.shop_exclusive_coin_expiring']) {
        final target = notificationTarget(type);
        expect(target, isNotNull, reason: type);
        expect(target!.mode, AppMode.customer, reason: type);
      }
    });

    test('merchant-facing types switch to Business mode and land on the right screen', () {
      expect(notificationTarget('redemption.awaiting_verification'), const NotificationTarget(BusinessRoutes.purchases, AppMode.business));
      expect(notificationTarget('redemption.merchant_settled'), const NotificationTarget(BusinessRoutes.purchases, AppMode.business));
      expect(notificationTarget('payment.successful'), const NotificationTarget(BusinessRoutes.payments, AppMode.business));
      expect(notificationTarget('payment.invoice_available'), const NotificationTarget(BusinessRoutes.invoices, AppMode.business));
      expect(notificationTarget('subscription.activated'), const NotificationTarget(BusinessRoutes.subscriptions, AppMode.business));
      expect(notificationTarget('offer_redemption.requested'), const NotificationTarget(BusinessRoutes.offerRedemptions, AppMode.business));
      expect(notificationTarget('prize.won'), const NotificationTarget(BusinessRoutes.prizes, AppMode.business));
      expect(notificationTarget('merchant.approved'), const NotificationTarget(BusinessRoutes.profile, AppMode.business));
      expect(notificationTarget('merchant.rejected'), const NotificationTarget(BusinessRoutes.profile, AppMode.business));
    });

    test('an unmapped/future type is a safe no-op, not a crash', () {
      expect(notificationTarget('something.new'), isNull);
    });
  });

  group('NotificationsScreen tap navigation', () {
    const account = Account(
      id: 1,
      mobileNumber: '+919990003001',
      status: 'active',
      isSuperAdmin: false,
      roles: ['customer', 'merchant_owner'],
      customerProfile: null,
      merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
    );

    AppNotification notif({required int id, required String type, required String title, bool unread = false}) => AppNotification(
          id: id,
          channel: 'in_app',
          type: type,
          title: title,
          body: 'body',
          data: const {},
          status: unread ? 'delivered' : 'read',
          sentAt: DateTime(2026, 1, 1),
          readAt: unread ? null : DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        );

    Widget wrap({required List<AppNotification> items, required _MemoryStorage storage}) {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: '/purchases', builder: (_, _) => const Text('purchases-list')),
          GoRoute(path: BusinessRoutes.payments, builder: (_, _) => const Text('business-payments')),
        ],
      );
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _AuthenticatedController(account)),
          secureStorageServiceProvider.overrideWithValue(storage),
          notificationsControllerProvider.overrideWith(() => _FakeNotifications(items)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
    }

    testWidgets('a customer-mode notification, already in Customer mode, pushes straight to its screen', (tester) async {
      final storage = _MemoryStorage()..store['app_mode'] = 'customer';
      await tester.pumpWidget(wrap(items: [notif(id: 1, type: 'purchase.recorded', title: 'Purchase recorded')], storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Purchase recorded'));
      await tester.pumpAndSettle();

      expect(find.text('purchases-list'), findsOneWidget);
      expect(storage.store['app_mode'], 'customer');
    });

    testWidgets('a business-mode notification switches the app to Business mode and opens its screen', (tester) async {
      final storage = _MemoryStorage();
      await tester.pumpWidget(wrap(items: [notif(id: 2, type: 'payment.successful', title: 'Payment successful')], storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payment successful'));
      await tester.pumpAndSettle();

      expect(find.text('business-payments'), findsOneWidget);
      expect(storage.store['app_mode'], 'business');
    });
  });
}

class _MemoryStorage implements SecureStorageService {
  final Map<String, String> store = {};
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> delete(String key) async => store.remove(key);
}

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(this._account);
  final Account _account;
  @override
  AuthState build() => AuthAuthenticated(_account);
}

class _FakeNotifications extends NotificationsController {
  _FakeNotifications(this._items);
  final List<AppNotification> _items;
  @override
  Future<NotificationsListState> build() async => NotificationsListState(items: _items, nextCursor: null);
}
