import 'prize.dart';

/// Mirrors `DrawResource`'s exact shape. A customer only ever sees a
/// `complete` draw (the backend's `viewPublicSummary` policy). Since BR-44
/// a complete draw's full story is public: the association, every prize
/// with how many units went in and were won, the sponsor shops, the pool
/// size, how many entries each shop contributed, and who coordinated and
/// witnessed it (names only -- numbers never leave the back office).
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
    this.associationName,
    this.poolSize,
    this.sponsorShops = const [],
    this.entriesByShop = const [],
    this.merchantScopes = const [],
    this.coordinatorName,
    this.witnessNames = const [],
  });

  factory Draw.fromJson(Map<String, dynamic> json) {
    final association = json['association'] as Map<String, dynamic>?;
    return Draw(
      id: json['id'] as int,
      associationId: json['association_id'] as int,
      associationName: association?['name'] as String?,
      cadence: json['cadence'] as String,
      scope: json['scope'] as String,
      status: json['status'] as String,
      poolLockedAt: json['pool_locked_at'] != null ? DateTime.tryParse(json['pool_locked_at'] as String) : null,
      executedAt: json['executed_at'] != null ? DateTime.tryParse(json['executed_at'] as String) : null,
      prizes: (json['prizes'] as List<dynamic>? ?? []).map((e) => Prize.fromJson(e as Map<String, dynamic>)).toList(),
      winnerCount: json['winner_count'] as int?,
      poolSize: json['pool_size'] as int?,
      sponsorShops: (json['sponsor_shops'] as List<dynamic>? ?? [])
          .map((e) => DrawSponsorShop.fromJson(e as Map<String, dynamic>))
          .toList(),
      entriesByShop: (json['entries_by_shop'] as List<dynamic>? ?? [])
          .map((e) => DrawShopEntries.fromJson(e as Map<String, dynamic>))
          .toList(),
      merchantScopes: (json['merchant_scopes'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .toList(),
      coordinatorName: json['coordinator_name'] as String?,
      witnessNames: (json['witnesses'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .toList(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int associationId;
  final String? associationName;
  final String cadence;
  final String scope;
  final String status;
  final DateTime? poolLockedAt;
  final DateTime? executedAt;
  final List<Prize> prizes;
  final int? winnerCount;
  final int? poolSize;
  final List<DrawSponsorShop> sponsorShops;
  final List<DrawShopEntries> entriesByShop;

  /// Shop names when the draw was limited to selected businesses.
  final List<String> merchantScopes;
  final String? coordinatorName;
  final List<String> witnessNames;
  final DateTime? createdAt;

  bool get isComplete => status == 'complete';

  int get unitsAwarded => prizes.fold(0, (sum, prize) => sum + (prize.unitsAwarded ?? 0));

  int get unitsInDraw => prizes.fold(0, (sum, prize) => sum + prize.unitsInDraw);
}

/// One shop that sponsored a prize in a draw (`DrawResource.sponsor_shops`).
class DrawSponsorShop {
  const DrawSponsorShop({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.prizeNames,
    required this.unitsAwarded,
  });

  factory DrawSponsorShop.fromJson(Map<String, dynamic> json) {
    return DrawSponsorShop(
      id: json['id'] as int,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      prizeNames: (json['prize_names'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      unitsAwarded: json['units_awarded'] as int? ?? 0,
    );
  }

  final int id;
  final String name;
  final String? logoUrl;
  final List<String> prizeNames;
  final int unitsAwarded;
}

/// Entry count per shop the coupons were earned at (`entries_by_shop`).
/// `id` is null for coupons with no shop (campaign or referral coupons).
class DrawShopEntries {
  const DrawShopEntries({required this.id, required this.name, required this.entries});

  factory DrawShopEntries.fromJson(Map<String, dynamic> json) {
    return DrawShopEntries(
      id: json['id'] as int?,
      name: json['name'] as String? ?? 'Other',
      entries: json['entries'] as int? ?? 0,
    );
  }

  final int? id;
  final String name;
  final int entries;
}
