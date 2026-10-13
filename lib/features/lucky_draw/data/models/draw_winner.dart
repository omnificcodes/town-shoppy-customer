import 'prize.dart';

/// Mirrors `DrawWinnerResource`'s exact shape. `winnerLabel` is always a
/// masked identifier (e.g. "Priya S."). Since BR-44 the backend ALSO sends
/// `winnerName`, `winnerMobileNumber` and the full `couponCode` to the
/// people allowed to hand the prize over -- the association's admins and
/// the owner or staff of the shop that sponsored THAT prize -- and leaves
/// them out entirely for everyone else, who get the code as `****` plus
/// its last four characters. The app shows whatever it was given.
class DrawWinner {
  const DrawWinner({
    required this.id,
    required this.drawId,
    required this.prize,
    required this.winnerLabel,
    required this.status,
    required this.selectedAt,
    this.winnerName,
    this.winnerMobileNumber,
    this.couponCode,
    this.earnedAtShopName,
    this.claimStatus,
    this.claimedAt,
  });

  factory DrawWinner.fromJson(Map<String, dynamic> json) {
    final shop = json['earned_at_shop'] as Map<String, dynamic>?;
    return DrawWinner(
      id: json['id'] as int,
      drawId: json['draw_id'] as int,
      prize: json['prize'] is Map ? Prize.fromJson(json['prize'] as Map<String, dynamic>) : null,
      winnerLabel: json['winner_label'] as String,
      winnerName: json['winner_name'] as String?,
      winnerMobileNumber: json['winner_mobile_number'] as String?,
      couponCode: json['coupon_code'] as String?,
      earnedAtShopName: shop?['name'] as String?,
      claimStatus: json['claim_status'] as String?,
      claimedAt: json['claimed_at'] != null ? DateTime.tryParse(json['claimed_at'] as String) : null,
      status: json['status'] as String,
      selectedAt: json['selected_at'] != null ? DateTime.tryParse(json['selected_at'] as String) : null,
    );
  }

  final int id;
  final int drawId;
  final Prize? prize;
  final String winnerLabel;
  final String? winnerName;
  final String? winnerMobileNumber;
  final String? couponCode;
  final String? earnedAtShopName;
  final String? claimStatus;
  final DateTime? claimedAt;
  final String status;
  final DateTime? selectedAt;

  /// The full name when this caller may see it, the masked label otherwise.
  String get displayName => winnerName ?? winnerLabel;

  /// Whether this caller got the hand-over details (name and number).
  bool get hasFullDetails => winnerName != null || winnerMobileNumber != null;
}
