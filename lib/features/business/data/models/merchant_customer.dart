import '../../../purchases/data/models/purchase.dart';
import '../../../redemptions/data/models/redemption.dart';

/// One row of `GET /customers` (`MerchantCustomerResource`) -- every figure
/// is scoped to THIS merchant only, never a platform-wide total.
class MerchantCustomer {
  const MerchantCustomer({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.purchaseCount,
    required this.totalSpent,
    required this.couponsEarned,
    required this.lastPurchaseAt,
  });

  factory MerchantCustomer.fromJson(Map<String, dynamic> json) {
    return MerchantCustomer(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Customer',
      mobileNumber: json['mobile_number'] as String?,
      purchaseCount: json['purchase_count'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      couponsEarned: json['coupons_earned'] as int? ?? 0,
      lastPurchaseAt: json['last_purchase_at'] is String ? DateTime.tryParse(json['last_purchase_at'] as String) : null,
    );
  }

  final int id;
  final String name;
  final String? mobileNumber;
  final int purchaseCount;
  final double totalSpent;
  final int couponsEarned;
  final DateTime? lastPurchaseAt;
}

/// `meta.totals` of `GET /customers`, over the whole filtered set.
class CustomerTotals {
  const CustomerTotals({required this.customers, required this.purchases, required this.spent, required this.coupons});

  factory CustomerTotals.fromJson(Map<String, dynamic>? json) {
    return CustomerTotals(
      customers: json?['customers'] as int? ?? 0,
      purchases: json?['purchases'] as int? ?? 0,
      spent: (json?['spent'] as num?)?.toDouble() ?? 0,
      coupons: json?['coupons'] as int? ?? 0,
    );
  }

  static const empty = CustomerTotals(customers: 0, purchases: 0, spent: 0, coupons: 0);

  final int customers;
  final int purchases;
  final double spent;
  final int coupons;
}

/// `GET /customers/{id}` -- a hand-built payload, not a Resource: the
/// customer, their stats at this merchant, and their full purchase and
/// redemption history here (unpaginated).
class MerchantCustomerDetail {
  const MerchantCustomerDetail({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.referralCode,
    required this.memberSince,
    required this.purchaseCount,
    required this.totalSpent,
    required this.couponsEarned,
    required this.redemptionCount,
    required this.totalDiscountRedeemed,
    required this.firstVisitAt,
    required this.lastVisitAt,
    required this.purchases,
    required this.redemptions,
  });

  factory MerchantCustomerDetail.fromJson(Map<String, dynamic> json) {
    final c = json['customer'] as Map<String, dynamic>? ?? const {};
    final s = json['stats'] as Map<String, dynamic>? ?? const {};
    DateTime? date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
    return MerchantCustomerDetail(
      id: c['id'] as int? ?? 0,
      name: c['name'] as String? ?? 'Customer',
      mobileNumber: c['mobile_number'] as String?,
      referralCode: c['referral_code'] as String?,
      memberSince: date(c['member_since']),
      purchaseCount: s['purchase_count'] as int? ?? 0,
      totalSpent: (s['total_spent'] as num?)?.toDouble() ?? 0,
      couponsEarned: s['coupons_earned'] as int? ?? 0,
      redemptionCount: s['redemption_count'] as int? ?? 0,
      totalDiscountRedeemed: (s['total_discount_redeemed'] as num?)?.toDouble() ?? 0,
      firstVisitAt: date(s['first_visit_at']),
      lastVisitAt: date(s['last_visit_at']),
      purchases: (json['purchases'] as List<dynamic>? ?? const []).map((e) => Purchase.fromJson(e as Map<String, dynamic>)).toList(),
      redemptions: (json['redemptions'] as List<dynamic>? ?? const []).map((e) => Redemption.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final int id;
  final String name;
  final String? mobileNumber;
  final String? referralCode;
  final DateTime? memberSince;
  final int purchaseCount;
  final double totalSpent;
  final int couponsEarned;
  final int redemptionCount;
  final double totalDiscountRedeemed;
  final DateTime? firstVisitAt;
  final DateTime? lastVisitAt;
  final List<Purchase> purchases;
  final List<Redemption> redemptions;
}
