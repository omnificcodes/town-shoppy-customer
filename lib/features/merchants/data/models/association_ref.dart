import 'town_ref.dart';

/// Mirrors `App\Domain\Merchant\Http\Resources\AssociationResource`'s public
/// shape -- both as nested inside a merchant and as a row of the public
/// `GET /associations` list. Never includes `contact_email`/`contact_phone`
/// — the backend's own resource docblock notes those are
/// association-internal, not part of the public view.
class AssociationRef {
  const AssociationRef({
    required this.id,
    required this.name,
    required this.slug,
    required this.town,
    this.shortCode,
    this.logoUrl,
  });

  factory AssociationRef.fromJson(Map<String, dynamic> json) {
    return AssociationRef(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      town: json['town'] is Map ? TownRef.fromJson(json['town'] as Map<String, dynamic>) : null,
      shortCode: json['short_code'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }

  final int id;
  final String name;
  final String slug;
  final TownRef? town;

  /// The federation's own abbreviation ("KVVES"), when it has one.
  final String? shortCode;
  final String? logoUrl;
}
