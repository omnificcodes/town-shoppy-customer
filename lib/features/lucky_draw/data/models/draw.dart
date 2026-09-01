import 'prize.dart';

/// Mirrors `DrawResource`'s exact shape. A customer only ever sees a
/// `complete` draw (the backend's `viewPublicSummary` policy) -- `poolSize`
/// and `randomizationAuditRef` are manager-only fields that resolve to
/// `null` for a customer caller, matching the resource's own
/// `$this->when($isManager, ...)` gating.
class Draw {
  const Draw({
    required this.id,
    required this.associationId,
    required this.cadence,
    required this.scope,
    required this.status,
    required this.poolLockedAt,
    required this.executedAt,
    required this.prizes,
    required this.winnerCount,
    required this.createdAt,
  });

  factory Draw.fromJson(Map<String, dynamic> json) {
    return Draw(
      id: json['id'] as int,
      associationId: json['association_id'] as int,
      cadence: json['cadence'] as String,
      scope: json['scope'] as String,
      status: json['status'] as String,
      poolLockedAt: json['pool_locked_at'] != null ? DateTime.tryParse(json['pool_locked_at'] as String) : null,
      executedAt: json['executed_at'] != null ? DateTime.tryParse(json['executed_at'] as String) : null,
      prizes: (json['prizes'] as List<dynamic>? ?? []).map((e) => Prize.fromJson(e as Map<String, dynamic>)).toList(),
      winnerCount: json['winner_count'] as int?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int associationId;
  final String cadence;
  final String scope;
  final String status;
  final DateTime? poolLockedAt;
  final DateTime? executedAt;
  final List<Prize> prizes;
  final int? winnerCount;
  final DateTime? createdAt;

  bool get isComplete => status == 'complete';
}
