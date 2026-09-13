/// Mirrors `PrizeResource` for the sponsoring merchant. `winners` is present
/// only on `GET /prizes/{id}`; `sponsorMerchantName` is absent on the
/// mutation responses.
class BusinessPrize {
  const BusinessPrize({
    required this.id,
    required this.sponsorMerchantId,
    required this.sponsorMerchantName,
    required this.associationId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.value,
    required this.quantityTotal,
    required this.quantityRemaining,
    required this.status,
    required this.winners,
    required this.createdAt,
  });

  factory BusinessPrize.fromJson(Map<String, dynamic> json) {
    final sponsor = json['sponsor_merchant'] as Map<String, dynamic>?;
    return BusinessPrize(
      id: json['id'] as int,
      sponsorMerchantId: sponsor?['id'] as int? ?? 0,
      sponsorMerchantName: sponsor?['name'] as String?,
      associationId: json['association_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Prize',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      quantityTotal: json['quantity_total'] as int? ?? 0,
      quantityRemaining: json['quantity_remaining'] as int? ?? 0,
      status: json['status'] as String? ?? 'draft',
      winners: json['winners'] is List
          ? (json['winners'] as List<dynamic>).map((e) => PrizeWinner.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      createdAt: json['created_at'] is String ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int sponsorMerchantId;
  final String? sponsorMerchantName;
  final int associationId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double? value;
  final int quantityTotal;
  final int quantityRemaining;

  /// `draft | available | allocated | awarded | withdrawn`.
  final String status;
  final List<PrizeWinner>? winners;
  final DateTime? createdAt;

  /// Withdraw is allowed from draft or available (`PrizeStatus` machine).
  bool get canWithdraw => status == 'draft' || status == 'available';
}

class PrizeWinner {
  const PrizeWinner({required this.voucherId, required this.winnerLabel, required this.claimStatus, required this.claimedAt});

  factory PrizeWinner.fromJson(Map<String, dynamic> json) {
    return PrizeWinner(
      voucherId: json['voucher_id'] as int? ?? 0,
      winnerLabel: json['winner_label'] as String?,
      claimStatus: json['claim_status'] as String? ?? 'issued',
      claimedAt: json['claimed_at'] is String ? DateTime.tryParse(json['claimed_at'] as String) : null,
    );
  }

  final int voucherId;
  final String? winnerLabel;
  final String claimStatus;
  final DateTime? claimedAt;
}

/// `meta.totals` of `GET /prizes` -- the backend's keys are named after
/// the merchant-facing meaning: `approved` = available, `pending` = draft,
/// `rejected` = withdrawn.
class PrizeTotals {
  const PrizeTotals({required this.prizes, required this.approved, required this.pending, required this.rejected});

  factory PrizeTotals.fromJson(Map<String, dynamic>? json) {
    return PrizeTotals(
      prizes: json?['prizes'] as int? ?? 0,
      approved: json?['approved'] as int? ?? 0,
      pending: json?['pending'] as int? ?? 0,
      rejected: json?['rejected'] as int? ?? 0,
    );
  }

  static const empty = PrizeTotals(prizes: 0, approved: 0, pending: 0, rejected: 0);

  final int prizes;
  final int approved;
  final int pending;
  final int rejected;
}

/// `POST /prizes` body. `association_id` is the merchant's own approving
/// association (from `GET /merchants/{id}`), never chosen by the user.
class PrizeInput {
  const PrizeInput({required this.name, required this.quantityTotal, this.description, this.imageUrl, this.value});

  final String name;
  final int quantityTotal;
  final String? description;
  final String? imageUrl;
  final double? value;

  Map<String, dynamic> toJson({required int merchantId, required int associationId}) {
    String? orNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'merchant_id': merchantId,
      'association_id': associationId,
      'name': name.trim(),
      'description': orNull(description),
      'image_url': orNull(imageUrl),
      'value': value,
      'quantity_total': quantityTotal,
    };
  }
}
