/// `POST /payments/subscriptions/intent`'s response -- everything the
/// native Razorpay checkout SDK needs to open its sheet. `key` is a public
/// identifier (it ships to Razorpay's own client-side widgets), never a
/// secret, so it is safe to hold in app state and pass straight to the SDK.
class SubscriptionCheckoutIntent {
  const SubscriptionCheckoutIntent({
    required this.paymentId,
    required this.subscriptionId,
    required this.key,
    required this.orderId,
    required this.amountInPaise,
    required this.currency,
  });

  factory SubscriptionCheckoutIntent.fromJson(Map<String, dynamic> json) {
    final payload = json['gateway_checkout_payload'] is Map ? Map<String, dynamic>.from(json['gateway_checkout_payload'] as Map) : const <String, dynamic>{};
    return SubscriptionCheckoutIntent(
      paymentId: json['payment_id'] as int,
      subscriptionId: json['subscription_id'] as int,
      key: payload['key'] as String? ?? '',
      orderId: payload['order_id'] as String? ?? '',
      amountInPaise: (payload['amount'] as num?)?.toInt() ?? 0,
      currency: payload['currency'] as String? ?? 'INR',
    );
  }

  /// This app's internal Payment record id -- the path parameter for the
  /// later `POST /payments/{id}/verify` call. Distinct from the Razorpay
  /// payment id the SDK hands back on success.
  final int paymentId;
  final int subscriptionId;
  final String key;
  final String orderId;
  final int amountInPaise;
  final String currency;
}
