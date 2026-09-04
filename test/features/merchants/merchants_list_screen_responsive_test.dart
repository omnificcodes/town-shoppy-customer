import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchants_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

/// Mirrors the small per-file fake convention already used in
/// `merchants_list_controller_test.dart` -- a single scripted page is all
/// this responsive sweep needs.
class _FakeMerchantsRepository implements MerchantsRepository {
  _FakeMerchantsRepository(this._page);

  final OffsetPage<Merchant> _page;

  @override
  Future<OffsetPage<Merchant>> list({int page = 1, int perPage = 20, int? categoryId, bool? acceptsTownCoin, bool? featured}) async => _page;

  @override
  Future<Merchant> show(int id) async => throw UnimplementedError();

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => throw UnimplementedError();

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

Merchant _longNameMerchant() {
  return const Merchant(
    id: 1,
    name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
    description: null,
    logoUrl: null,
    websiteUrl: null,
    socialLinks: null,
    discountRate: 12.5,
    acceptsTownCoin: true,
    category: MerchantCategory(id: 1, name: 'Food & Beverage', slug: 'food-beverage'),
    association: AssociationRef(
      id: 1,
      name: 'Downtown',
      slug: 'downtown',
      town: TownRef(id: 1, name: 'Springfield-on-the-Hudson Metropolitan Area', slug: 'springfield', stateRegion: null),
    ),
    branch: null,
  );
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      merchantCategoriesProvider.overrideWith((ref) async => []),
      merchantsRepositoryProvider.overrideWithValue(
        _FakeMerchantsRepository(OffsetPage(items: [_longNameMerchant()], currentPage: 1, lastPage: 1, total: 1)),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MerchantsListScreen()),
  );
}

Widget _wrapEmpty() {
  return ProviderScope(
    overrides: [
      merchantCategoriesProvider.overrideWith((ref) async => []),
      merchantsRepositoryProvider.overrideWithValue(
        _FakeMerchantsRepository(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0)),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MerchantsListScreen()),
  );
}

void main() {
  testWidgets('MerchantsListScreen renders a long merchant name/category/town without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Discover merchants'), findsOneWidget);
        expect(find.textContaining('The Grand Downtown'), findsOneWidget);
        expect(find.textContaining('% off with Town Coin'), findsOneWidget);
      },
    );
  });

  testWidgets('MerchantsListScreen shows the discovery empty state without overflow at every mandated viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrapEmpty,
      verify: (tester, size) async {
        expect(find.text('No participating merchants found'), findsOneWidget);
      },
    );
  });
}
