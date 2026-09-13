/// `GET /purchases/stats` (`PurchaseStatsService::forMerchants`): recorded
/// purchases for the caller's own merchant, bucketed by day/week/month
/// depending on [range]. Deliberately NOT package-gated on the backend so
/// the dashboard works for a shop that has not subscribed yet.
class PurchaseStats {
  const PurchaseStats({required this.range, required this.from, required this.total, required this.trend, required this.byBranch});

  factory PurchaseStats.fromJson(Map<String, dynamic> json) {
    return PurchaseStats(
      range: json['range'] as String? ?? '30d',
      from: json['from'] as String?,
      total: json['total'] as int? ?? 0,
      trend: (json['trend'] as List<dynamic>? ?? const [])
          .map((e) => PurchaseTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      byBranch: (json['breakdown_by_branch'] as List<dynamic>? ?? const [])
          .map((e) => BranchPurchaseCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// `7d | 30d | 3mo | 1yr` -- the only values the backend accepts.
  final String range;
  final String? from;
  final int total;
  final List<PurchaseTrendPoint> trend;
  final List<BranchPurchaseCount> byBranch;

  static const ranges = ['7d', '30d', '3mo', '1yr'];

  static String rangeLabel(String range) => switch (range) {
        '7d' => '7 days',
        '30d' => '30 days',
        '3mo' => '3 months',
        '1yr' => '1 year',
        _ => range,
      };
}

class PurchaseTrendPoint {
  const PurchaseTrendPoint({required this.date, required this.count});

  factory PurchaseTrendPoint.fromJson(Map<String, dynamic> json) {
    return PurchaseTrendPoint(date: json['date'] as String? ?? '', count: json['count'] as int? ?? 0);
  }

  /// `YYYY-MM-DD` bucket start.
  final String date;
  final int count;
}

class BranchPurchaseCount {
  const BranchPurchaseCount({required this.branchId, required this.branchName, required this.count});

  factory BranchPurchaseCount.fromJson(Map<String, dynamic> json) {
    return BranchPurchaseCount(
      branchId: json['branch_id'] as int? ?? 0,
      branchName: json['branch_name'] as String? ?? 'Branch',
      count: json['count'] as int? ?? 0,
    );
  }

  final int branchId;
  final String branchName;
  final int count;
}
