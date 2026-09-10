/// One `(coupon, cadence)` eligibility row -- a coupon can be `closed`/`won`
/// for `weekly` while still `active` for `monthly`/`mega` simultaneously.
/// Mirrors `CouponEligibility`, embedded in `CouponResource`'s
/// `eligibilities` field.
class CouponEligibility {
  const CouponEligibility({required this.cadence, required this.status});

  factory CouponEligibility.fromJson(Map<String, dynamic> json) {
    return CouponEligibility(cadence: json['cadence'] as String, status: json['status'] as String);
  }

  final String cadence;
  final String status;

  bool get isActive => status == 'active';
}

/// The merchant a coupon's purchase was made at -- null for a coupon with
/// no purchase behind it (e.g. a referral-milestone bonus, which
/// `CouponIssuanceService::issueReferralBonus()` never attaches a merchant
/// to). Same `{id, name, logo_url}` shape `Offer`'s embedded merchant uses.
class CouponMerchantRef {
  const CouponMerchantRef({required this.id, required this.name, required this.logoUrl});

  factory CouponMerchantRef.fromJson(Map<String, dynamic> json) {
    return CouponMerchantRef(
      id: json['id'] as int,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }

  final int id;
  final String name;
  final String? logoUrl;
}

/// Mirrors `CouponResource`'s exact customer-facing shape (`GET /coupons`,
/// `GET /coupons/{coupon}`) -- deliberately never the wider
/// `CouponAdminResource` fields (customer/purchase refs), which only a
/// Super Admin's listing ever receives.
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.status,
    required this.sourceType,
    required this.eligibilities,
    required this.merchant,
    required this.issuedAt,
    required this.annualCycleExpiresAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    final merchantJson = json['merchant'] as Map<String, dynamic>?;

    return Coupon(
      id: json['id'] as int,
      code: json['code'] as String,
      status: json['status'] as String,
      sourceType: json['source_type'] as String,
      eligibilities: (json['eligibilities'] as List<dynamic>? ?? [])
          .map((e) => CouponEligibility.fromJson(e as Map<String, dynamic>))
          .toList(),
      merchant: merchantJson != null ? CouponMerchantRef.fromJson(merchantJson) : null,
      issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at'] as String) : null,
      annualCycleExpiresAt: json['annual_cycle_expires_at'] != null
          ? DateTime.tryParse(json['annual_cycle_expires_at'] as String)
          : null,
    );
  }

  final int id;
  final String code;
  final String status;
  final String sourceType;
  final List<CouponEligibility> eligibilities;
  final CouponMerchantRef? merchant;
  final DateTime? issuedAt;
  final DateTime? annualCycleExpiresAt;

  bool get isActive => status == 'active';
  bool get isWon => status == 'won';
  bool get isExpired => status == 'expired';

  CouponEligibility? eligibilityFor(String cadence) {
    for (final eligibility in eligibilities) {
      if (eligibility.cadence == cadence) return eligibility;
    }
    return null;
  }
}
