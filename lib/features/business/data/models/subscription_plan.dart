/// One row of a plan card, as the API renders it (`items` on
/// `SubscriptionPlanResource`, BR-43): the label and the printed value, so
/// the app never needs its own label map.
class PlanItem {
  const PlanItem({
    required this.key,
    required this.label,
    required this.group,
    required this.groupLabel,
    required this.type,
    required this.enabled,
    required this.display,
    this.value,
    this.amount,
    this.enforced = true,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    key: json['key'] as String,
    label: json['label'] as String? ?? '',
    group: json['group'] as String? ?? '',
    groupLabel: json['group_label'] as String? ?? '',
    type: json['type'] as String? ?? 'toggle',
    enabled: json['enabled'] as bool? ?? false,
    display: json['display'] as String? ?? '',
    value: (json['value'] as num?)?.toInt(),
    amount: (json['amount'] as num?)?.toDouble(),
    enforced: json['enforced'] as bool? ?? true,
  );

  final String key;
  final String label;
  final String group;
  final String groupLabel;

  /// `toggle | count | percent | perk`.
  final String type;
  final bool enabled;

  /// "250 / month", "50%", "Unlimited", "₹1,500.00 per draw".
  final String display;
  final int? value;
  final double? amount;
  final bool enforced;

  /// Whether the card prints a value beside the label.
  bool get showsValue => type == 'count' || type == 'percent' || (type == 'perk' && amount != null);

  /// "Lucky Draw coupons · 75 / month" or just "Magic Google review link".
  String get line => showsValue ? '$label · $display' : label;
}

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
    this.description,
    this.badgeLabel,
    this.trialDays = 0,
    this.items = const [],
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] is Map ? Map<String, dynamic>.from(json['features'] as Map) : const <String, dynamic>{};
    return SubscriptionPlan(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      badgeLabel: json['badge_label'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      billingCycle: json['billing_cycle'] as String? ?? '',
      trialDays: json['trial_days'] as int? ?? 0,
      couponQuotaMonthly: json['coupon_quota_monthly'] as int?,
      features: {for (final e in rawFeatures.entries) e.key: e.value == true},
      items: json['items'] is List ? (json['items'] as List).whereType<Map>().map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
      status: json['status'] as String? ?? 'active',
    );
  }

  final int id;
  final String code;
  final String name;
  final String? description;

  /// Optional ribbon on the card ("Most popular").
  final String? badgeLabel;
  final double price;
  final String currency;
  final String billingCycle;

  /// 0 = no trial; N = the first N days are free.
  final int trialDays;

  /// `null` means unlimited coupons.
  final int? couponQuotaMonthly;

  /// Every switch by plan column -- kept for older callers; cards render [items].
  final Map<String, bool> features;

  /// One row per catalogue item, in display order.
  final List<PlanItem> items;
  final String status;

  bool get isActive => status == 'active';
  bool get hasTrial => trialDays > 0;
  bool get isFree => price <= 0;

  /// The switched-on items, in catalogue order.
  List<PlanItem> get includedItems => [for (final i in items) if (i.enabled) i];

  /// Included items grouped the way the catalogue groups them, in order.
  Map<String, List<PlanItem>> get includedByGroup {
    final out = <String, List<PlanItem>>{};
    for (final item in includedItems) {
      out.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    return out;
  }

  /// Labels of the switched-on items ("Lucky Draw coupons · 75 / month").
  List<String> get enabledFeatureLabels => [for (final i in includedItems) i.line];
}
