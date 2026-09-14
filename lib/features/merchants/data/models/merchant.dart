import 'association_ref.dart';
import 'merchant_branch_ref.dart';
import 'merchant_business_hours.dart';
import 'merchant_category.dart';
import 'town_ref.dart';

/// Mirrors `App\Domain\Merchant\Http\Resources\MerchantPublicResource`
/// exactly — the only shape a customer (or a guest) ever receives from
/// `GET /merchants` / `GET /merchants/{id}` (`MerchantController::index()`'s
/// `isPrivileged` check requires Super Admin or Association Admin
/// specifically; a customer or merchant-owner/staff account gets this same
/// public resource). Never includes `owner_name`, `gst_number`,
/// `verified_at`, `rejection_reason`, or `duplicate_flag_notes` — those
/// exist only on `MerchantPrivateResource`, which this app never reaches.
///
/// `branch` is still only the merchant's single primary branch (unchanged in
/// `MerchantPublicResource` itself) — for the full, active-only branch list,
/// see `merchantBranchesProvider` / `GET /merchants/{id}/branches` (Phase 4).
///
/// `contactMobileNumber` is the merchant's own published contact number
/// (deliberately public, unlike `owner_name`/`gst_number` — see
/// `MerchantPublicResource`'s docblock), used for the detail screen's
/// tap-to-call action.
///
/// [tagline], [coverImageUrl] and [businessHours] were always in the API
/// response; the app just hadn't read them until the Stitch redesign, whose
/// shop cards show a cover photo and whether a shop is open. All three are
/// optional, so existing call sites are unaffected.
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.websiteUrl,
    required this.contactMobileNumber,
    required this.socialLinks,
    required this.discountRate,
    required this.acceptsTownCoin,
    required this.category,
    required this.association,
    required this.branch,
    this.tagline,
    this.coverImageUrl,
    this.businessHours,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      contactMobileNumber: json['contact_mobile_number'] as String?,
      socialLinks: json['social_links'] is Map ? Map<String, dynamic>.from(json['social_links'] as Map) : null,
      discountRate: json['discount_rate'] != null ? (json['discount_rate'] as num).toDouble() : null,
      acceptsTownCoin: json['accepts_town_coin'] as bool? ?? false,
      category: json['category'] is Map ? MerchantCategory.fromJson(json['category'] as Map<String, dynamic>) : null,
      association: json['association'] is Map ? AssociationRef.fromJson(json['association'] as Map<String, dynamic>) : null,
      branch: json['branch'] is Map ? MerchantBranchRef.fromJson(json['branch'] as Map<String, dynamic>) : null,
      tagline: json['tagline'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      businessHours: MerchantBusinessHours.tryParse(json['business_hours']),
    );
  }

  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? contactMobileNumber;
  final Map<String, dynamic>? socialLinks;
  final double? discountRate;
  final bool acceptsTownCoin;
  final MerchantCategory? category;
  final AssociationRef? association;
  final MerchantBranchRef? branch;
  final String? tagline;
  final String? coverImageUrl;

  /// Null when the merchant never set hours -- "unknown", not "closed".
  final MerchantBusinessHours? businessHours;

  TownRef? get town => association?.town;
}
