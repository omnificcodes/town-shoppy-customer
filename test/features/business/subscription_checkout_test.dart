import 'package:customer/features/business/application/subscription_checkout_controller.dart';
import 'package:customer/features/business/data/models/subscription_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionCheckoutIntent', () {
    test('parses the gateway_checkout_payload envelope from POST /payments/subscriptions/intent', () {
      final intent = SubscriptionCheckoutIntent.fromJson({
        'payment_id': 41,
        'subscription_id': 10,
        'gateway_checkout_payload': {'key': 'rzp_test_TbEV5uqMeZLRKr', 'order_id': 'order_uqJ5bUY7lhiLim', 'amount': 50000, 'currency': 'INR'},
      });
      expect(intent.paymentId, 41);
      expect(intent.subscriptionId, 10);
      expect(intent.key, 'rzp_test_TbEV5uqMeZLRKr');
      expect(intent.orderId, 'order_uqJ5bUY7lhiLim');
      expect(intent.amountInPaise, 50000);
      expect(intent.currency, 'INR');
    });

    test('missing payload fields fall back to safe empty values rather than crashing', () {
      final intent = SubscriptionCheckoutIntent.fromJson({'payment_id': 1, 'subscription_id': 2});
      expect(intent.key, '');
      expect(intent.orderId, '');
      expect(intent.amountInPaise, 0);
      expect(intent.currency, 'INR');
    });
  });

  group('SubscriptionCheckoutState', () {
    test('isBusyFor is true only for the plan currently in flight', () {
      const state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.awaitingPayment, planId: 5);
      expect(state.isBusyFor(5), isTrue);
      expect(state.isBusyFor(6), isFalse);
      expect(state.isBusy, isTrue);
    });

    test('idle and terminal (success/error) states are not busy', () {
      expect(const SubscriptionCheckoutState().isBusy, isFalse);
      expect(const SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.success, planId: 5).isBusyFor(5), isFalse);
      expect(const SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.error, planId: 5).isBusyFor(5), isFalse);
    });

    test('isErrorFor matches only the plan the error belongs to', () {
      const state = SubscriptionCheckoutState(status: SubscriptionCheckoutStatus.error, planId: 5);
      expect(state.isErrorFor(5), isTrue);
      expect(state.isErrorFor(6), isFalse);
    });
  });
}
