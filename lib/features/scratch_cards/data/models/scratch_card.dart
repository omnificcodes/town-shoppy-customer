/// Mirrors `CustomerScratchCardResource` -- a scratch card in the
/// customer's hand. [reward] is null until the card is scratched: the
/// server keeps the surprise, not the app.
class CustomerScratchCard {
  const CustomerScratchCard({
    required this.id,
    required this.title,
    required this.theme,
    required this.status,
    required this.merchantId,
    this.merchantName,
    this.merchantLogoUrl,
    this.customerName,
    this.customerMobileNumber,
    this.purchaseId,
    this.reward,
    this.coinsCredited,
    this.expiresAt,
    this.scratchedAt,
    this.redeemedAt,
    this.createdAt,
  });

  factory CustomerScratchCard.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final reward = json['reward'] as Map<String, dynamic>?;
    return CustomerScratchCard(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Scratch card',
      theme: json['theme'] as String? ?? 'gold',
      status: json['status'] as String? ?? 'unscratched',
      merchantId: merchant?['id'] as int? ?? 0,
      merchantName: merchant?['name'] as String?,
      merchantLogoUrl: merchant?['logo_url'] as String?,
      customerName: customer?['name'] as String?,
      customerMobileNumber: customer?['mobile_number'] as String?,
      purchaseId: json['purchase_id'] as int?,
      reward: reward == null ? null : ScratchCardReward.fromJson(reward),
      coinsCredited: json['coins_credited'] as int?,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      scratchedAt: json['scratched_at'] != null ? DateTime.tryParse(json['scratched_at'] as String) : null,
      redeemedAt: json['redeemed_at'] != null ? DateTime.tryParse(json['redeemed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String title;
  final String theme;

  /// `unscratched | scratched | redeemed | expired` (expiry folded in by the server).
  final String status;
  final int merchantId;
  final String? merchantName;
  final String? merchantLogoUrl;
  final String? customerName;
  final String? customerMobileNumber;
  final int? purchaseId;
  final ScratchCardReward? reward;
  final int? coinsCredited;
  final DateTime? expiresAt;
  final DateTime? scratchedAt;
  final DateTime? redeemedAt;
  final DateTime? createdAt;

  bool get isUnscratched => status == 'unscratched';
  bool get isExpired => status == 'expired';
  bool get isRedeemed => status == 'redeemed';

  /// Offer cards wait to be shown at the counter; coin cards are complete
  /// once scratched.
  bool get awaitsRedemption => status == 'scratched' && reward?.isOffer == true;

  String get shopName => merchantName ?? 'the shop';
}

class ScratchCardReward {
  const ScratchCardReward({required this.type, this.offerText, this.coinAmount, this.code});

  factory ScratchCardReward.fromJson(Map<String, dynamic> json) => ScratchCardReward(
    type: json['type'] as String? ?? 'offer',
    offerText: json['offer_text'] as String?,
    coinAmount: json['coin_amount'] as int?,
    code: json['code'] as String?,
  );

  /// `offer | coins`.
  final String type;
  final String? offerText;
  final int? coinAmount;
  final String? code;

  bool get isOffer => type == 'offer';
  bool get isCoins => type == 'coins';

  /// The 8-character code split for reading out: `ABCD-EFGH`.
  String get formattedCode {
    final c = code ?? '';
    return c.length == 8 ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
  }
}

/// Mirrors `ScratchCardResource` -- one of the shop's designs.
class ScratchCardDesign {
  const ScratchCardDesign({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.rewardType,
    required this.validityDays,
    required this.theme,
    required this.status,
    this.offerText,
    this.coinAmount,
    this.givenCount = 0,
    this.scratchedCount = 0,
    this.redeemedCount = 0,
  });

  factory ScratchCardDesign.fromJson(Map<String, dynamic> json) => ScratchCardDesign(
    id: json['id'] as int,
    merchantId: json['merchant_id'] as int,
    title: json['title'] as String,
    rewardType: json['reward_type'] as String? ?? 'offer',
    offerText: json['offer_text'] as String?,
    coinAmount: json['coin_amount'] as int?,
    validityDays: json['validity_days'] as int? ?? 30,
    theme: json['theme'] as String? ?? 'gold',
    status: json['status'] as String? ?? 'active',
    givenCount: json['given_count'] as int? ?? 0,
    scratchedCount: json['scratched_count'] as int? ?? 0,
    redeemedCount: json['redeemed_count'] as int? ?? 0,
  );

  final int id;
  final int merchantId;
  final String title;
  final String rewardType;
  final String? offerText;
  final int? coinAmount;
  final int validityDays;
  final String theme;
  final String status;
  final int givenCount;
  final int scratchedCount;
  final int redeemedCount;

  bool get isActive => status == 'active';
  bool get isCoins => rewardType == 'coins';

  /// What the card gives, in a few words, for lists and pickers.
  String get rewardSummary => isCoins ? '$coinAmount Town Coins' : (offerText ?? '');
}

/// The shop's designs plus what its plan allows right now.
class ScratchCardDesigns {
  const ScratchCardDesigns({required this.items, required this.enabled, required this.remaining});

  final List<ScratchCardDesign> items;

  /// Whether the shop's plan includes scratch cards at all.
  final bool enabled;

  /// Cards left this billing month; null = the plan sets no limit.
  final int? remaining;

  List<ScratchCardDesign> get active => items.where((d) => d.isActive).toList();

  /// The counter can give a card: the plan allows it, at least one design is
  /// active, and the month's allowance is not used up.
  bool get canGive => enabled && active.isNotEmpty && (remaining == null || remaining! > 0);
}

/// Body for `POST /scratch-cards` / `PATCH /scratch-cards/{id}`.
class ScratchCardDesignInput {
  const ScratchCardDesignInput({
    required this.title,
    required this.rewardType,
    required this.validityDays,
    required this.theme,
    this.offerText,
    this.coinAmount,
    this.status = 'active',
  });

  final String title;
  final String rewardType;
  final String? offerText;
  final int? coinAmount;
  final int validityDays;
  final String theme;
  final String status;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'reward_type': rewardType,
    'offer_text': rewardType == 'offer' ? offerText?.trim() : null,
    'coin_amount': rewardType == 'coins' ? coinAmount : null,
    'validity_days': validityDays,
    'theme': theme,
    'status': status,
  };
}
