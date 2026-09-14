import '../data/models/offer.dart';

/// "20% OFF" or "₹50 OFF", or null when the offer carries no discount value
/// (an announcement or a buy-one-get-one, say).
String? offerDiscountLabel(Offer offer) {
  final value = offer.discountValue;
  if (value == null) return null;

  final formatted = value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return offer.offerType == 'fixed_discount' ? '₹${_groupIndian(formatted)} OFF' : '$formatted% OFF';
}

/// Indian digit grouping for the whole-rupee part: 1500 -> 1,500,
/// 150000 -> 1,50,000. Any decimals are kept as they are.
String _groupIndian(String amount) {
  final dot = amount.indexOf('.');
  final whole = dot == -1 ? amount : amount.substring(0, dot);
  final fraction = dot == -1 ? '' : amount.substring(dot);
  if (whole.length <= 3) return amount;

  final lastThree = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$lastThree$fraction';
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

/// A reader-facing name for the API's `offer_type`.
String offerTypeLabel(Offer offer) => switch (offer.offerType) {
      'percentage_discount' => 'Percentage off',
      'fixed_discount' => 'Flat discount',
      'announcement' => 'Announcement',
      _ => 'Offer',
    };

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Till 12 Oct", or null when the offer has no end date.
String? offerValidTillLabel(DateTime? endsAt) {
  if (endsAt == null) return null;
  final local = endsAt.toLocal();
  return 'Till ${local.day} ${_months[local.month - 1]}';
}
