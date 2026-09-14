import '../data/models/offer.dart';

/// "20% OFF" or "₹50 OFF", or null when the offer carries no discount value
/// (an announcement or a buy-one-get-one, say).
String? offerDiscountLabel(Offer offer) {
  final value = offer.discountValue;
  if (value == null) return null;

  final formatted = value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return offer.offerType == 'fixed_discount' ? '₹$formatted OFF' : '$formatted% OFF';
}

/// "Ends in 3d", "Ends today", or "Limited time" when there is no end date.
/// [now] exists for tests.
String offerEndsInLabel(DateTime? endsAt, {DateTime? now}) {
  if (endsAt == null) return 'Limited time';

  final remaining = endsAt.difference(now ?? DateTime.now());
  if (remaining.isNegative) return 'Ending soon';
  if (remaining.inHours < 24) return 'Ends today';
  return 'Ends in ${remaining.inDays}d';
}
