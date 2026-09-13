import '../../../merchants/data/models/association_ref.dart';
import '../../../merchants/data/models/merchant_branch_ref.dart';
import '../../../merchants/data/models/merchant_category.dart';
import 'business_hours.dart';

/// Mirrors `App\Domain\Merchant\Http\Resources\MerchantPrivateResource` --
/// the shape `GET /merchants/{id}` returns to the merchant's own owner or
/// staff (the public `Merchant` model elsewhere in this app is the guest/
/// customer view and never carries `status`, `owner_name`, `gst_number`,
/// `rejection_reason`, ...). Business mode works exclusively with this one.
///
/// `category` / `association` / `branch` are absent (not null) on the few
/// responses built without relations loaded (the status-transition
/// endpoints); every read this app performs eager-loads them.
class BusinessMerchant {
  const BusinessMerchant({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.logoUrl,
    required this.coverImageUrl,
    required this.websiteUrl,
    required this.contactMobileNumber,
    required this.contactEmail,
    required this.socialLinks,
    required this.businessHours,
    required this.discountRate,
    required this.acceptsTownCoin,
    required this.isFeatured,
    required this.category,
    required this.association,
    required this.branch,
    required this.ownerName,
    required this.gstNumber,
    required this.status,
    required this.verifiedAt,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory BusinessMerchant.fromJson(Map<String, dynamic> json) {
    return BusinessMerchant(
      id: json['id'] as int,
      name: json['name'] as String,
      tagline: json['tagline'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      contactMobileNumber: json['contact_mobile_number'] as String?,
      contactEmail: json['contact_email'] as String?,
      socialLinks: json['social_links'] is Map
          ? Map<String, dynamic>.from(json['social_links'] as Map).map((k, v) => MapEntry(k, v.toString()))
          : null,
      businessHours: json['business_hours'] is Map
          ? BusinessHours.fromJson(Map<String, dynamic>.from(json['business_hours'] as Map))
          : null,
      discountRate: json['discount_rate'] != null ? (json['discount_rate'] as num).toDouble() : null,
      acceptsTownCoin: json['accepts_town_coin'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      category: json['category'] is Map ? MerchantCategory.fromJson(json['category'] as Map<String, dynamic>) : null,
      association: json['association'] is Map ? AssociationRef.fromJson(json['association'] as Map<String, dynamic>) : null,
      branch: json['branch'] is Map ? MerchantBranchRef.fromJson(json['branch'] as Map<String, dynamic>) : null,
      ownerName: json['owner_name'] as String?,
      gstNumber: json['gst_number'] as String?,
      status: json['status'] as String? ?? 'pending',
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String name;
  final String? tagline;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? websiteUrl;
  final String? contactMobileNumber;
  final String? contactEmail;
  final Map<String, String>? socialLinks;
  final BusinessHours? businessHours;
  final double? discountRate;
  final bool acceptsTownCoin;
  final bool isFeatured;
  final MerchantCategory? category;
  final AssociationRef? association;
  final MerchantBranchRef? branch;
  final String? ownerName;
  final String? gstNumber;

  /// `pending | active | suspended | rejected | inactive | subscription_expired`
  /// (`MerchantStatus`).
  final String status;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  String? get townName => association?.town?.name;
}
