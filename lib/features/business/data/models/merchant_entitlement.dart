/// `GET /subscriptions/entitlement` -- readable by Owner and Staff alike,
/// never 403s. The one source of truth for "is this shop on a package",
/// exactly as the merchant web app's `getMerchantPackage()` treats it.
class MerchantEntitlement {
  const MerchantEntitlement({
    required this.hasPackage,
    required this.status,
    required this.planName,
    required this.inGracePeriod,
    this.planCode,
    this.trialEndsAt,
    this.features = const {},
    this.productCoupons = false,
    this.maxCouponsPerProduct,
    this.scratchCards = false,
    this.scratchCardsRemaining = 0,
    this.stampCards = false,
    this.stampCardLimit = 0,
    this.reviewLinks = false,
  });

  factory MerchantEntitlement.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] is Map ? Map<String, dynamic>.from(json['features'] as Map) : const <String, dynamic>{};
    return MerchantEntitlement(
      hasPackage: json['has_package'] as bool? ?? false,
      status: json['status'] as String?,
      planName: json['plan_name'] as String?,
      planCode: json['plan_code'] as String?,
      inGracePeriod: json['in_grace_period'] as bool? ?? false,
      trialEndsAt: json['trial_ends_at'] is String ? DateTime.tryParse(json['trial_ends_at'] as String) : null,
      features: {
        for (final e in rawFeatures.entries)
          if (e.value is bool || e.value is num || e.value == null) e.key: e.value is num ? (e.value as num).toInt() : e.value,
      },
      productCoupons: json['product_coupons'] as bool? ?? false,
      maxCouponsPerProduct: json['max_coupons_per_product'] as int?,
      scratchCards: json['scratch_cards'] as bool? ?? false,
      scratchCardsRemaining: json['scratch_cards_remaining'] as int?,
      stampCards: json['stamp_cards'] as bool? ?? false,
      stampCardLimit: json['stamp_card_limit'] as int?,
      reviewLinks: json['review_links'] as bool? ?? false,
    );
  }

  /// What the web app falls back to when the entitlement call itself fails:
  /// fail OPEN, so a transient error never locks a paying shop out of its
  /// counter -- the backend still answers 402 on every gated route. With
  /// no feature map, [has] answers true for the same reason.
  static const failOpen = MerchantEntitlement(hasPackage: true, status: null, planName: null, inGracePeriod: false);

  final bool hasPackage;
  final String? status;
  final String? planName;
  final String? planCode;
  final bool inGracePeriod;

  /// Set while the current period is a free trial.
  final DateTime? trialEndsAt;

  /// BR-43: every plan item by catalogue key -- `true`/`false` for a
  /// switch, an `int` for a count/percent, `null` for "unlimited" (count)
  /// or "use the global setting" (percent). Empty with no package, or when
  /// the call failed (see [failOpen]).
  final Map<String, Object?> features;

  /// Whether the shop's plan lets it attach Lucky Draw coupons to products,
  /// and the most one product may carry (null = no ceiling of its own).
  final bool productCoupons;
  final int? maxCouponsPerProduct;

  /// Whether the plan lets the shop give scratch cards, and how many are
  /// left this billing month (null = no limit, 0 = none or feature off).
  final bool scratchCards;
  final int? scratchCardsRemaining;

  /// Whether the plan lets the shop run stamp cards, and how many at once
  /// (null = no limit, 0 = feature off).
  final bool stampCards;
  final int? stampCardLimit;

  /// Whether the plan includes the magic review link.
  final bool reviewLinks;

  bool get isTrial => trialEndsAt != null;

  /// Whether the plan carries [key]. A count counts as on when it is
  /// unlimited (null) or above 0. With no map at all (fail-open) every
  /// item is treated as on; without a package nothing is.
  bool has(String key) {
    if (!hasPackage) return false;
    if (features.isEmpty) return true;
    final value = features[key];
    if (value is bool) return value;
    if (value is int) return value > 0;
    return features.containsKey(key); // null = unlimited / global
  }

  /// A count item's limit: null = unlimited (or unknown), 0 = off.
  int? limit(String key) {
    final value = features[key];
    return value is int ? value : null;
  }
}
