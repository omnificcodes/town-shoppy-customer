import 'prize.dart';

/// Mirrors `VoucherResource`'s exact shape -- never includes `qr_secret`
/// (that returns exactly once, only from `GET /vouchers/{id}/qr`, same
/// one-deliberate-route pattern as Purchase QR / Customer QR / Redemption
/// QR).
class Voucher {
  const Voucher({
    required this.id,
    required this.code,
    required this.prize,
    required this.sponsorMerchantName,
    required this.status,
    required this.expiresAt,
    required this.claimedAt,
    required this.createdAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    final sponsor = json['sponsor_merchant'] as Map<String, dynamic>?;
    return Voucher(
      id: json['id'] as int,
      code: json['code'] as String,
      prize: json['prize'] is Map ? Prize.fromJson(json['prize'] as Map<String, dynamic>) : null,
      sponsorMerchantName: sponsor?['name'] as String?,
      status: json['status'] as String,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      claimedAt: json['claimed_at'] != null ? DateTime.tryParse(json['claimed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String code;
  final Prize? prize;
  final String? sponsorMerchantName;
  final String status;
  final DateTime? expiresAt;
  final DateTime? claimedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isClaimed => status == 'claimed';
}
