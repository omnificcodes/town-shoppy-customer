import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';

/// In-memory stand-in for [FavoritesRepository]. Any widget test that pumps
/// a merchant card or the merchant detail bar renders a `FavoriteButton`,
/// which loads the saved-id set — without this override that load reaches
/// for the real Dio client and leaves a timer pending.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository({Set<int>? saved, this.merchants = const [], this.failWrites = false}) : saved = saved ?? {};

  final Set<int> saved;
  final List<Merchant> merchants;
  final bool failWrites;

  @override
  Future<Set<int>> ids() async => {...saved};

  @override
  Future<OffsetPage<Merchant>> list({int page = 1, int perPage = 20}) async {
    final items = merchants.where((m) => saved.contains(m.id)).toList();
    return OffsetPage(items: items, currentPage: 1, lastPage: 1, total: items.length);
  }

  @override
  Future<void> add(int merchantId) async {
    if (failWrites) throw StateError('write refused');
    saved.add(merchantId);
  }

  @override
  Future<void> remove(int merchantId) async {
    if (failWrites) throw StateError('write refused');
    saved.remove(merchantId);
  }
}
