import '../../../merchants/data/models/merchant.dart';

/// Who a counter purchase is being requested from, and how the customer
/// got there -- the two ways into `POST /purchases/requests`.
///
/// The distinction is not cosmetic. A scanned token is the server's proof
/// the customer is standing at that counter; a merchant chosen from its
/// own profile ("Pay bill with coins") carries no such proof, and the
/// server relies on the merchant's approval of the bill instead. The
/// request screen behaves the same either way; only what it sends differs.
///
/// Travels as a GoRouter `extra`. On web GoRouter JSON-encodes extras into
/// browser history and silently drops anything it cannot encode, handing
/// the route `null` on the next rebuild -- so every variant is
/// JSON-encodable ([toJson]) and the route rebuilds it from the decoded
/// map with [fromExtra]. Only plain ids survive that trip; a profile
/// snapshot does not, and the controller refetches from the ids instead.
sealed class PurchaseRequestTarget {
  const PurchaseRequestTarget();

  /// The raw Purchase QR token the customer just scanned.
  const factory PurchaseRequestTarget.scanned(String token) = ScannedPurchaseTarget;

  /// A merchant the customer is already looking at, no scan. The profile
  /// rides along so the form is ready at once, without a round trip.
  factory PurchaseRequestTarget.merchant(Merchant merchant) =>
      MerchantPurchaseTarget(merchantId: merchant.id, branchId: merchant.branch?.id, merchant: merchant);

  /// The same, when all that is known is the merchant's id -- the
  /// controller fetches the profile before the form can show.
  factory PurchaseRequestTarget.merchantId(int merchantId, {int? branchId}) =>
      MerchantPurchaseTarget(merchantId: merchantId, branchId: branchId);

  /// A route `extra` as GoRouter hands it back: the object itself, or the
  /// JSON map it was serialised to for browser history.
  static PurchaseRequestTarget fromExtra(Object? extra) {
    return switch (extra) {
      PurchaseRequestTarget target => target,
      Map<String, dynamic> json => fromJson(json),
      Map<Object?, Object?> json => fromJson(json.cast<String, dynamic>()),
      _ => throw ArgumentError.value(extra, 'extra', 'A purchase request needs a PurchaseRequestTarget'),
    };
  }

  static PurchaseRequestTarget fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'scanned' => ScannedPurchaseTarget(json['token'] as String),
      'merchant' => MerchantPurchaseTarget(
        merchantId: (json['merchant_id'] as num).toInt(),
        branchId: (json['branch_id'] as num?)?.toInt(),
      ),
      final type => throw ArgumentError.value(type, 'type', 'Unknown purchase request target'),
    };
  }

  /// The fields that name the target in the request body.
  Map<String, dynamic> toRequestJson();

  /// What survives a trip through browser history -- see the class note.
  Map<String, dynamic> toJson();
}

final class ScannedPurchaseTarget extends PurchaseRequestTarget {
  const ScannedPurchaseTarget(this.token);

  final String token;

  @override
  Map<String, dynamic> toRequestJson() => {'token': token};

  @override
  Map<String, dynamic> toJson() => {'type': 'scanned', 'token': token};
}

final class MerchantPurchaseTarget extends PurchaseRequestTarget {
  const MerchantPurchaseTarget({required this.merchantId, this.branchId, this.merchant});

  final int merchantId;

  /// The profile only knows the primary branch; the server falls back to
  /// it anyway when this is absent, so this is a hint, not a claim.
  final int? branchId;

  /// The profile the customer was looking at, when it made the trip. Null
  /// after a browser round trip, in which case it is fetched by id.
  final Merchant? merchant;

  @override
  Map<String, dynamic> toRequestJson() => {'merchant_id': merchantId, if (branchId != null) 'branch_id': branchId};

  @override
  Map<String, dynamic> toJson() => {
    'type': 'merchant',
    'merchant_id': merchantId,
    if (branchId != null) 'branch_id': branchId,
  };
}
