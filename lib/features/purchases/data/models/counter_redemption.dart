/// The coin half of a counter purchase — `meta.redemption` from
/// `POST /purchases/requests` when `redeem` was sent.
///
/// [applied] is false for the ordinary cases where there was nothing to
/// spend (a customer with no coins, a merchant who does not take them).
/// That is not an error: the purchase request itself still succeeded, and
/// the customer simply pays the full bill.
class CounterRedemption {
  const CounterRedemption({
    required this.applied,
    this.reason,
    this.id,
    this.discountAmount,
    this.coinsRequested,
    this.amountPayable,
    this.pin,
    this.expiresAt,
  });

  factory CounterRedemption.fromJson(Map<String, dynamic> json) {
    final applied = json['applied'] as bool? ?? false;

    if (!applied) {
      return CounterRedemption(applied: false, reason: json['reason'] as String?);
    }

    return CounterRedemption(
      applied: true,
      id: json['id'] as int?,
      // Money crosses the wire as a string, so it is parsed rather than
      // read as a num -- the same shape the rest of this app expects.
      discountAmount: double.tryParse('${json['discount_amount']}'),
      coinsRequested: json['coins_requested'] as int?,
      amountPayable: double.tryParse('${json['amount_payable']}'),
      pin: json['pin'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
    );
  }

  final bool applied;

  /// Why no coins were spent, when [applied] is false. Server-worded.
  final String? reason;

  final int? id;
  final double? discountAmount;
  final int? coinsRequested;
  final double? amountPayable;

  /// Returned exactly once, at creation. The merchant can settle without
  /// it; this is the fallback for a merchant who wants to check the
  /// customer really raised this.
  final String? pin;

  final DateTime? expiresAt;
}
