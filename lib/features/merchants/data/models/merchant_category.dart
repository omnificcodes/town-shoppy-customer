/// Mirrors `App\Domain\Merchant\Http\Resources\MerchantCategoryResource` —
/// `id`/`name`/`slug` only. The backend has no category hierarchy, images,
/// merchant counts, or explicit ordering (`GET /merchant-categories` sorts
/// by name and returns only `status = active` rows) — nothing beyond these
/// three fields is invented here.
class MerchantCategory {
  const MerchantCategory({required this.id, required this.name, required this.slug});

  factory MerchantCategory.fromJson(Map<String, dynamic> json) {
    return MerchantCategory(id: json['id'] as int, name: json['name'] as String, slug: json['slug'] as String);
  }

  final int id;
  final String name;
  final String slug;
}
