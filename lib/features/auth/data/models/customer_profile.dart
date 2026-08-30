/// Mirrors `App\Domain\Customer\Http\Resources\CustomerProfileResource`
/// exactly — the backend's Slice 1 scope note applies here too: only
/// name/referral_code/status exist today. There is no address, DOB,
/// gender, photo, or email field on the backend yet, and no update
/// endpoint — see `docs/customer-api-contract.md` for the gap.
class CustomerProfile {
  const CustomerProfile({required this.id, required this.name, required this.referralCode, required this.status});

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as int,
      name: json['name'] as String?,
      referralCode: json['referral_code'] as String?,
      status: json['status'] as String,
    );
  }

  final int id;
  final String? name;
  final String? referralCode;
  final String status;
}
