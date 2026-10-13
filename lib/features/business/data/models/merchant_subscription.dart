import 'subscription_plan.dart';

/// Mirrors `SubscriptionResource` (`GET /subscriptions/me`, Owner only;
/// `data: null` when the shop has never subscribed).
class MerchantSubscription {
  const MerchantSubscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.couponQuotaUsed,
    required this.couponQuotaRemaining,
    required this.pendingPlan,
    required this.pendingPlanChangeAt,
    required this.cancelledAt,
    this.trialEndsAt,
    this.renewalOpen = false,
  });

  factory MerchantSubscription.fromJson(Map<String, dynamic> json) {
    return MerchantSubscription(
      id: json['id'] as int,
      plan: json['plan'] is Map ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>) : null,
      status: json['status'] as String? ?? '',
      currentPeriodStart: _date(json['current_period_start']),
      currentPeriodEnd: _date(json['current_period_end']),
      couponQuotaUsed: json['coupon_quota_used'] as int? ?? 0,
      couponQuotaRemaining: json['coupon_quota_remaining'] as int?,
      pendingPlan: json['pending_plan'] is Map ? SubscriptionPlan.fromJson(json['pending_plan'] as Map<String, dynamic>) : null,
      pendingPlanChangeAt: _date(json['pending_plan_change_at']),
      cancelledAt: _date(json['cancelled_at']),
      trialEndsAt: _date(json['trial_ends_at']),
      renewalOpen: json['renewal_open'] as bool? ?? false,
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;

  final int id;
  final SubscriptionPlan? plan;

  /// `active | grace_period | past_due | suspended | expired | cancelled`.
  final String status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final int couponQuotaUsed;

  /// `null` = unlimited.
  final int? couponQuotaRemaining;
  final SubscriptionPlan? pendingPlan;
  final DateTime? pendingPlanChangeAt;
  final DateTime? cancelledAt;

  /// BR-43: set while the current period is a free trial.
  final DateTime? trialEndsAt;

  /// Whether the owner may pay for the same plan right now (trial, or the
  /// renewal window before the period ends).
  final bool renewalOpen;

  bool get isTrial => trialEndsAt != null;

  bool get grantsFullService => status == 'active' || status == 'grace_period';
}
