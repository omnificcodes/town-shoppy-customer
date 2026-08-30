/// One row of referral history — either an outbound referral (someone this
/// customer referred) or the single `referred_by` slot (who referred this
/// customer), both shaped by `ReferralResource`. `reward_coins_referrer`/
/// `reward_coins_referred` are only present once a reward was actually
/// granted — the ledger amount is never guessed client-side.
class ReferralHistoryEntry {
  const ReferralHistoryEntry({
    required this.id,
    required this.referrerName,
    required this.referredName,
    required this.status,
    required this.qualifiedAt,
    required this.rewardCoinsReferrer,
    required this.rewardCoinsReferred,
    required this.bonusCouponIssued,
    required this.createdAt,
  });

  factory ReferralHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReferralHistoryEntry(
      id: json['id'] as int,
      referrerName: json['referrer_name'] as String?,
      referredName: json['referred_name'] as String?,
      status: json['status'] as String,
      qualifiedAt: json['qualified_at'] != null ? DateTime.tryParse(json['qualified_at'] as String) : null,
      rewardCoinsReferrer: json['reward_coins_referrer'] as int?,
      rewardCoinsReferred: json['reward_coins_referred'] as int?,
      bonusCouponIssued: json['bonus_coupon_issued'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String? referrerName;
  final String? referredName;
  final String status;
  final DateTime? qualifiedAt;
  final int? rewardCoinsReferrer;
  final int? rewardCoinsReferred;
  final bool bonusCouponIssued;
  final DateTime? createdAt;
}

/// Mirrors `ReferralController::me()`'s response shape exactly (see that
/// controller's own docblock — this is the one and only referral endpoint
/// the backend exposes for a customer).
class ReferralSummary {
  const ReferralSummary({
    required this.referralCode,
    required this.referralLink,
    required this.qualifiedCount,
    required this.pendingCount,
    required this.bonusCouponsEarned,
    required this.milestoneReferralCount,
    required this.nextMilestoneReferralsRemaining,
    required this.referrals,
    required this.referredBy,
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      referralCode: json['referral_code'] as String?,
      referralLink: json['referral_link'] as String?,
      qualifiedCount: json['qualified_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      bonusCouponsEarned: json['bonus_coupons_earned'] as int? ?? 0,
      milestoneReferralCount: json['milestone_referral_count'] as int? ?? 0,
      nextMilestoneReferralsRemaining: json['next_milestone_referrals_remaining'] as int?,
      referrals: (json['referrals'] as List<dynamic>? ?? [])
          .map((e) => ReferralHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      referredBy: json['referred_by'] != null ? ReferralHistoryEntry.fromJson(json['referred_by'] as Map<String, dynamic>) : null,
    );
  }

  final String? referralCode;
  final String? referralLink;
  final int qualifiedCount;
  final int pendingCount;
  final int bonusCouponsEarned;
  final int milestoneReferralCount;
  final int? nextMilestoneReferralsRemaining;
  final List<ReferralHistoryEntry> referrals;
  final ReferralHistoryEntry? referredBy;
}
