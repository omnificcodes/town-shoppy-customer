/// Mirrors `App\Domain\Offer\Http\Resources\OfferResource` -- the
/// merchant-side (management) view of an offer, which unlike the public
/// `Offer` model carries `status`, `created_by` and timestamps. Statuses
/// are exactly `draft | active | expired`; there is no quota, min-bill or
/// redemption count on the backend.
class BusinessOffer {
  const BusinessOffer({
    required this.id,
    required this.merchantId,
    required this.branchId,
    required this.branchName,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.offerType,
    required this.discountValue,
    required this.coinDiscountRate,
    required this.applicableItem,
    required this.isCoinRedeemable,
    this.isFlashSale = false,
    required this.terms,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessOffer.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    return BusinessOffer(
      id: json['id'] as int,
      merchantId: merchant?['id'] as int?,
      branchId: branch?['id'] as int?,
      branchName: branch?['name'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      offerType: json['offer_type'] as String? ?? 'announcement',
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      coinDiscountRate: (json['coin_discount_rate'] as num?)?.toDouble(),
      applicableItem: json['applicable_item'] as String?,
      isCoinRedeemable: json['is_coin_redeemable'] as bool? ?? false,
      isFlashSale: json['is_flash_sale'] as bool? ?? false,
      terms: json['terms'] as String?,
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      status: json['status'] as String? ?? 'draft',
      createdBy: json['created_by'] as String?,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;

  final int id;
  final int? merchantId;
  final int? branchId;
  final String? branchName;
  final String title;
  final String? description;
  final String? imageUrl;

  /// `announcement | percentage_discount | fixed_discount`.
  final String offerType;
  final double? discountValue;
  final double? coinDiscountRate;
  final String? applicableItem;
  final bool isCoinRedeemable;

  /// BR-43: shown with a countdown in the customer Home's Flash sales strip.
  final bool isFlashSale;
  final String? terms;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// `draft | active | expired`.
  final String status;

  /// `owner | staff`, or null for legacy rows.
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status == 'draft';
  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';

  /// "Live right now" is derived, never stored on the backend.
  bool get isLiveNow {
    final now = DateTime.now();
    return isActive && (startsAt == null || !startsAt!.isAfter(now)) && (endsAt == null || !endsAt!.isBefore(now));
  }
}

/// `meta.status_counts` on the management list -- computed before the
/// status filter so the tab counts stay stable while switching tabs.
class OfferStatusCounts {
  const OfferStatusCounts({required this.draft, required this.active, required this.expired});

  factory OfferStatusCounts.fromJson(Map<String, dynamic>? json) {
    return OfferStatusCounts(
      draft: json?['draft'] as int? ?? 0,
      active: json?['active'] as int? ?? 0,
      expired: json?['expired'] as int? ?? 0,
    );
  }

  static const empty = OfferStatusCounts(draft: 0, active: 0, expired: 0);

  final int draft;
  final int active;
  final int expired;

  int get total => draft + active + expired;
}

/// Body for `POST /offers` / `PATCH /offers/{id}` -- the exact field set the
/// merchant web app's form sends (offer type stays the backend default;
/// the web form never exposes it either).
class OfferInput {
  const OfferInput({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.imageUrl,
    this.terms,
    this.coinDiscountRate,
    this.applicableItem,
    this.branchId,
    this.isFlashSale = false,
  });

  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? description;
  final String? imageUrl;
  final String? terms;

  /// `null` = customers cannot redeem coins on this offer.
  final double? coinDiscountRate;
  final String? applicableItem;
  final int? branchId;

  /// Only a plan with the flash-sale item may set this.
  final bool isFlashSale;

  Map<String, dynamic> toJson() {
    String? orNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'title': title.trim(),
      'description': orNull(description),
      'image_url': orNull(imageUrl),
      'terms': orNull(terms),
      'coin_discount_rate': coinDiscountRate,
      'applicable_item': orNull(applicableItem),
      'branch_id': branchId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'is_flash_sale': isFlashSale,
    };
  }
}
