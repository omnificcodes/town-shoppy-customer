/// Mirrors `App\Domain\Customer\Http\Resources\CustomerProfileResource`
/// exactly. `dateOfBirth`/`anniversaryDate`/`socialLinks` are the first
/// slice of "progressive profile completion" fields (address/gender/photo
/// remain unbuilt) -- every one of them, name included, is optional and
/// editable via `PATCH /customer-profile` (see `CustomerProfileRepository`).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.anniversaryDate,
    required this.socialLinks,
    required this.referralCode,
    required this.status,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as int,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'] as String) : null,
      anniversaryDate: json['anniversary_date'] != null ? DateTime.tryParse(json['anniversary_date'] as String) : null,
      socialLinks: (json['social_links'] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, value as String)),
      referralCode: json['referral_code'] as String?,
      status: json['status'] as String,
    );
  }

  final int id;
  final String? name;
  final DateTime? dateOfBirth;
  final DateTime? anniversaryDate;
  final Map<String, String>? socialLinks;
  final String? referralCode;
  final String status;
}
