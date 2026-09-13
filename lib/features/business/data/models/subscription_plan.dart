/// Mirrors `SubscriptionPlanResource` (`GET /subscriptions/plans`, public).
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.couponQuotaMonthly,
    required this.features,
    required this.status,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] is Map ? Map<String, dynamic>.from(json['features'] as Map) : const <String, dynamic>{};
    return SubscriptionPlan(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      billingCycle: json['billing_cycle'] as String? ?? '',
      couponQuotaMonthly: json['coupon_quota_monthly'] as int?,
      features: {for (final e in rawFeatures.entries) e.key: e.value == true},
      status: json['status'] as String? ?? 'active',
    );
  }

  final int id;
  final String code;
  final String name;
  final double price;
  final String currency;
  final String billingCycle;

  /// `null` means unlimited coupons.
  final int? couponQuotaMonthly;

  /// `whatsapp_broadcast`, `premium_placement`, `verified_badge`,
  /// `banner_placement`, `premium_support`, `self_scan_qr` -> enabled?
  final Map<String, bool> features;
  final String status;

  bool get isActive => status == 'active';

  List<String> get enabledFeatureLabels => [
        for (final e in features.entries)
          if (e.value) featureLabel(e.key),
      ];

  /// Same labels the merchant web app's `FEATURE_LABEL` map uses.
  static String featureLabel(String key) => switch (key) {
        'whatsapp_broadcast' => 'WhatsApp broadcast',
        'premium_placement' => 'Premium placement',
        'verified_badge' => 'Verified badge',
        'banner_placement' => 'Banner placement',
        'premium_support' => 'Premium support',
        'self_scan_qr' => 'Self-scan QR',
        _ => key.replaceAll('_', ' '),
      };
}
