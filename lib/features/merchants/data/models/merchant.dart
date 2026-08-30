import 'association_ref.dart';
import 'merchant_branch_ref.dart';
import 'merchant_category.dart';
import 'town_ref.dart';

/// Mirrors `App\Domain\Merchant\Http\Resources\MerchantPublicResource`
/// exactly — the only shape a customer (or a guest) ever receives from
/// `GET /merchants` / `GET /merchants/{id}` (`MerchantController::index()`'s
/// `isPrivileged` check requires Super Admin or Association Admin
/// specifically; a customer or merchant-owner/staff account gets this same
/// public resource). Never includes `owner_name`, `contact_mobile_number`,
/// `gst_number`, `verified_at`, `rejection_reason`, or
/// `duplicate_flag_notes` — those exist only on `MerchantPrivateResource`,
/// which this app never reaches.
///
/// `branch` is still only the merchant's single primary branch (unchanged in
/// `MerchantPublicResource` itself) — for the full, active-only branch list,
/// see `merchantBranchesProvider` / `GET /merchants/{id}/branches` (Phase 4).
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.websiteUrl,
    required this.socialLinks,
    required this.discountRate,
    required this.acceptsTownCoin,
    required this.category,
    required this.association,
    required this.branch,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      socialLinks: json['social_links'] is Map ? Map<String, dynamic>.from(json['social_links'] as Map) : null,
      discountRate: json['discount_rate'] != null ? (json['discount_rate'] as num).toDouble() : null,
      acceptsTownCoin: json['accepts_town_coin'] as bool? ?? false,
      category: json['category'] is Map ? MerchantCategory.fromJson(json['category'] as Map<String, dynamic>) : null,
      association: json['association'] is Map ? AssociationRef.fromJson(json['association'] as Map<String, dynamic>) : null,
      branch: json['branch'] is Map ? MerchantBranchRef.fromJson(json['branch'] as Map<String, dynamic>) : null,
    );
  }

  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final Map<String, dynamic>? socialLinks;
  final double? discountRate;
  final bool acceptsTownCoin;
  final MerchantCategory? category;
  final AssociationRef? association;
  final MerchantBranchRef? branch;

  TownRef? get town => association?.town;
}
