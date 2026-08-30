import 'merchant.dart';
import 'merchant_branch_ref.dart';

/// Mirrors `App\Domain\Merchant\Http\Resources\NearbyMerchantResource` --
/// the shape `GET /merchants/nearby` returns, distinct from the plain
/// `Merchant` list `GET /merchants` returns. [branch] is whichever branch
/// matched the search radius, which is not necessarily the same branch as
/// [merchant]'s own embedded `branch` (always that merchant's primary one).
class NearbyMerchant {
  const NearbyMerchant({required this.merchant, required this.branch, required this.distanceKm});

  factory NearbyMerchant.fromJson(Map<String, dynamic> json) {
    return NearbyMerchant(
      merchant: Merchant.fromJson(json['merchant'] as Map<String, dynamic>),
      branch: MerchantBranchRef.fromJson(json['branch'] as Map<String, dynamic>),
      distanceKm: (json['distance_km'] as num).toDouble(),
    );
  }

  final Merchant merchant;
  final MerchantBranchRef branch;
  final double distanceKm;
}
