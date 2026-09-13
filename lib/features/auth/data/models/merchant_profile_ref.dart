/// One entry of `AccountResource`'s `merchant_owner_profiles` /
/// `merchant_staff_profiles` arrays -- exactly the three fields the backend
/// renders there (`{id, merchant_id, status}`). There is deliberately no
/// nested merchant: name/logo/status come from `GET /merchants/{merchant_id}`
/// (see `myMerchantProvider`), same as the merchant web app does.
class MerchantProfileRef {
  const MerchantProfileRef({required this.id, required this.merchantId, required this.status});

  factory MerchantProfileRef.fromJson(Map<String, dynamic> json) {
    return MerchantProfileRef(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int,
      status: json['status'] as String,
    );
  }

  final int id;
  final int merchantId;
  final String status;

  bool get isActive => status == 'active';
}
