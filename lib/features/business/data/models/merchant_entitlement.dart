/// `GET /subscriptions/entitlement` -- readable by Owner and Staff alike,
/// never 403s. The one source of truth for "is this shop on a package",
/// exactly as the merchant web app's `getMerchantPackage()` treats it.
class MerchantEntitlement {
  const MerchantEntitlement({
    required this.hasPackage,
    required this.status,
    required this.planName,
    required this.inGracePeriod,
  });

  factory MerchantEntitlement.fromJson(Map<String, dynamic> json) {
    return MerchantEntitlement(
      hasPackage: json['has_package'] as bool? ?? false,
      status: json['status'] as String?,
      planName: json['plan_name'] as String?,
      inGracePeriod: json['in_grace_period'] as bool? ?? false,
    );
  }

  /// What the web app falls back to when the entitlement call itself fails:
  /// fail OPEN, so a transient error never locks a paying shop out of its
  /// counter -- the backend still answers 402 on every gated route.
  static const failOpen = MerchantEntitlement(hasPackage: true, status: null, planName: null, inGracePeriod: false);

  final bool hasPackage;
  final String? status;
  final String? planName;
  final bool inGracePeriod;
}
