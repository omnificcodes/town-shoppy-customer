import 'package:flutter/foundation.dart';

/// The catalog's filter pills. Every one of these is backed by a column
/// `GET /products` already has -- products carry no category/taxonomy, so
/// a "Butter Cookies"-style pill would have nothing behind it.
enum ProductFilter {
  all('All'),
  offers('Offers'),
  townCoin('Town Coin'),
  underHundred('Under ₹100');

  const ProductFilter(this.label);

  final String label;

  Map<String, dynamic> get queryParameters => switch (this) {
    ProductFilter.all => const {},
    ProductFilter.offers => const {'discounted': 1},
    ProductFilter.townCoin => const {'accepts_town_coin': 1},
    ProductFilter.underHundred => const {'max_price': 100},
  };
}

/// What the catalog is currently showing: an optional merchant scope, the
/// search term, and the selected pill. It is the list controller's family
/// key, so changing any part of it fetches (and caches) its own list.
@immutable
class ProductsQuery {
  const ProductsQuery({this.merchantId, this.search = '', this.filter = ProductFilter.all});

  final int? merchantId;

  /// Already trimmed by the caller; empty means "no search".
  final String search;

  final ProductFilter filter;

  bool get isFiltered => search.isNotEmpty || filter != ProductFilter.all;

  ProductsQuery copyWith({String? search, ProductFilter? filter}) =>
      ProductsQuery(merchantId: merchantId, search: search ?? this.search, filter: filter ?? this.filter);

  @override
  bool operator ==(Object other) =>
      other is ProductsQuery && other.merchantId == merchantId && other.search == search && other.filter == filter;

  @override
  int get hashCode => Object.hash(merchantId, search, filter);

  @override
  String toString() => 'ProductsQuery(merchantId: $merchantId, search: "$search", filter: ${filter.name})';
}
