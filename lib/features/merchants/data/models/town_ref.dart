/// Mirrors `App\Domain\Merchant\Http\Resources\TownResource`'s public shape
/// (as nested inside a merchant's `association.town`, or from `GET /towns`
/// itself) — `associations_count`/`merchants_count` are omitted here since
/// the public/customer path never computes them (`whenCounted`, only ever
/// populated for the Super-Admin management view).
class TownRef {
  const TownRef({required this.id, required this.name, required this.slug, required this.stateRegion});

  factory TownRef.fromJson(Map<String, dynamic> json) {
    return TownRef(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      stateRegion: json['state_region'] as String?,
    );
  }

  final int id;
  final String name;
  final String slug;
  final String? stateRegion;
}
