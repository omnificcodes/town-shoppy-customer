import 'prize.dart';

/// Mirrors `DrawWinnerResource`'s exact shape. `winnerLabel` is always a
/// masked identifier (e.g. "Priya S.") -- the backend never sends a full
/// name or mobile number here, by design (ADR-003 addendum's public-
/// transparency recommendation).
class DrawWinner {
  const DrawWinner({
    required this.id,
    required this.drawId,
    required this.prize,
    required this.winnerLabel,
    required this.status,
    required this.selectedAt,
  });

  factory DrawWinner.fromJson(Map<String, dynamic> json) {
    return DrawWinner(
      id: json['id'] as int,
      drawId: json['draw_id'] as int,
      prize: json['prize'] is Map ? Prize.fromJson(json['prize'] as Map<String, dynamic>) : null,
      winnerLabel: json['winner_label'] as String,
      status: json['status'] as String,
      selectedAt: json['selected_at'] != null ? DateTime.tryParse(json['selected_at'] as String) : null,
    );
  }

  final int id;
  final int drawId;
  final Prize? prize;
  final String winnerLabel;
  final String status;
  final DateTime? selectedAt;
}
