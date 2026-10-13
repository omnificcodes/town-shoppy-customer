/// Mirrors `CustomerStampCardResource` -- one customer's progress on one
/// of a shop's stamp cards: the target, the stamps so far, the reward.
class CustomerStampCard {
  const CustomerStampCard({
    required this.id,
    required this.stampCardId,
    required this.title,
    required this.icon,
    required this.merchantId,
    required this.stampsRequired,
    required this.stampsCount,
    required this.rewardText,
    required this.status,
    this.minBillAmount,
    this.merchantName,
    this.merchantLogoUrl,
    this.customerName,
    this.stamps = const [],
    this.completedAt,
    this.rewardedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerStampCard.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    return CustomerStampCard(
      id: json['id'] as int,
      stampCardId: json['stamp_card_id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Stamp card',
      icon: json['icon'] as String? ?? 'coffee',
      minBillAmount: (json['min_bill_amount'] as num?)?.toDouble(),
      merchantId: merchant?['id'] as int? ?? 0,
      merchantName: merchant?['name'] as String?,
      merchantLogoUrl: merchant?['logo_url'] as String?,
      customerName: customer?['name'] as String?,
      stampsRequired: json['stamps_required'] as int? ?? 0,
      stampsCount: json['stamps_count'] as int? ?? 0,
      rewardText: json['reward_text'] as String? ?? '',
      status: json['status'] as String? ?? 'collecting',
      stamps: (json['stamps'] as List<dynamic>? ?? const [])
          .map((e) => StampEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      rewardedAt: json['rewarded_at'] != null ? DateTime.tryParse(json['rewarded_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  final int id;
  final int stampCardId;
  final String title;
  final String icon;
  final double? minBillAmount;
  final int merchantId;
  final String? merchantName;
  final String? merchantLogoUrl;
  final String? customerName;
  final int stampsRequired;
  final int stampsCount;
  final String rewardText;

  /// `collecting | full | rewarded`.
  final String status;
  final List<StampEntry> stamps;
  final DateTime? completedAt;
  final DateTime? rewardedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFull => status == 'full';
  bool get isCollecting => status == 'collecting';
  bool get isRewarded => status == 'rewarded';

  /// Live = still in play (collecting or full); rewarded cards are history.
  bool get isLive => !isRewarded;

  int get remaining => (stampsRequired - stampsCount).clamp(0, stampsRequired);

  String get shopName => merchantName ?? 'the shop';
}

class StampEntry {
  const StampEntry({required this.id, this.purchaseId, this.givenAt});

  factory StampEntry.fromJson(Map<String, dynamic> json) => StampEntry(
    id: json['id'] as int,
    purchaseId: json['purchase_id'] as int?,
    givenAt: json['given_at'] != null ? DateTime.tryParse(json['given_at'] as String) : null,
  );

  final int id;
  final int? purchaseId;
  final DateTime? givenAt;
}

/// Mirrors `StampCardResource` -- one of the shop's stamp card programmes.
class StampCardProgramme {
  const StampCardProgramme({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.stampsRequired,
    required this.rewardText,
    required this.icon,
    required this.status,
    this.minBillAmount,
    this.collectingCount = 0,
    this.rewardedCount = 0,
  });

  factory StampCardProgramme.fromJson(Map<String, dynamic> json) => StampCardProgramme(
    id: json['id'] as int,
    merchantId: json['merchant_id'] as int,
    title: json['title'] as String,
    stampsRequired: json['stamps_required'] as int? ?? 5,
    rewardText: json['reward_text'] as String? ?? '',
    minBillAmount: (json['min_bill_amount'] as num?)?.toDouble(),
    icon: json['icon'] as String? ?? 'coffee',
    status: json['status'] as String? ?? 'active',
    collectingCount: json['collecting_count'] as int? ?? 0,
    rewardedCount: json['rewarded_count'] as int? ?? 0,
  );

  final int id;
  final int merchantId;
  final String title;
  final int stampsRequired;
  final String rewardText;
  final double? minBillAmount;
  final String icon;
  final String status;
  final int collectingCount;
  final int rewardedCount;

  bool get isActive => status == 'active';

  /// "5 stamps → Free coffee".
  String get summary => '$stampsRequired stamps → $rewardText';
}

/// The shop's programmes plus what its plan allows right now.
class StampCardProgrammes {
  const StampCardProgrammes({required this.items, required this.enabled, required this.limit, required this.activeCount});

  final List<StampCardProgramme> items;

  /// Whether the shop's plan includes stamp cards at all.
  final bool enabled;

  /// How many may run at once; null = no limit.
  final int? limit;
  final int activeCount;

  List<StampCardProgramme> get active => items.where((p) => p.isActive).toList();

  bool get canAddMore => enabled && (limit == null || activeCount < limit!);

  /// The counter can stamp: the plan allows it and a card is running.
  bool get canStamp => enabled && active.isNotEmpty;
}

/// Body for `POST /stamp-cards` / `PATCH /stamp-cards/{id}`.
class StampCardInput {
  const StampCardInput({
    required this.title,
    required this.stampsRequired,
    required this.rewardText,
    required this.icon,
    this.minBillAmount,
    this.status = 'active',
  });

  final String title;
  final int stampsRequired;
  final String rewardText;
  final double? minBillAmount;
  final String icon;
  final String status;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'stamps_required': stampsRequired,
    'reward_text': rewardText.trim(),
    'min_bill_amount': minBillAmount,
    'icon': icon,
    'status': status,
  };
}
