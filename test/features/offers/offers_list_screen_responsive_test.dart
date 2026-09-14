import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/offers/data/models/offer.dart';
import 'package:customer/features/offers/data/offers_repository.dart';
import 'package:customer/features/offers/presentation/offers_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

/// Records the filters each `list()` call carried, so the tests can prove
/// the tabs and category strip filter on the server, not in the widget.
class _FakeOffersRepository implements OffersRepository {
  final calls = <({int page, int? categoryId, int? expiringWithinDays})>[];

  @override
  Future<OffsetPage<Offer>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    int? expiringWithinDays,
    int? merchantId,
  }) async {
    calls.add((page: page, categoryId: categoryId, expiringWithinDays: expiringWithinDays));
    return OffsetPage(
      items: [_offer(1, coin: true), _offer(2), _announcement(3)],
      currentPage: 1,
      lastPage: 1,
      total: 3,
    );
  }

  @override
  Future<List<Offer>> nearby({required double latitude, required double longitude, int perPage = 10}) async =>
      throw UnimplementedError();

  @override
  Future<Offer> show(int id) async => throw UnimplementedError();
}

/// Worst-case lengths in every slot: the backend caps none of them.
Offer _offer(int id, {bool coin = false}) => Offer(
  id: id,
  merchantId: id,
  merchantName: 'The Grand Downtown Corner Cafe and Bakery Emporium',
  merchantLogoUrl: null,
  title: 'Weekend feast: flat 25% off across every cafe and bakery counter in the whole town',
  description: 'Valid on dine-in and takeaway orders above five hundred rupees, every weekend this month',
  imageUrl: null,
  offerType: id.isEven ? 'fixed_discount' : 'percentage_discount',
  discountValue: id.isEven ? 1500 : 12.5,
  terms: null,
  startsAt: null,
  endsAt: DateTime.now().add(const Duration(days: 14)),
  distanceKm: null,
  coinDiscountRate: coin ? 7.5 : null,
  applicableItem: null,
  isCoinRedeemable: coin,
);

Offer _announcement(int id) => Offer(
  id: id,
  merchantId: id,
  merchantName: 'Alathur Silks',
  merchantLogoUrl: null,
  title: 'Onam collection now in store',
  description: null,
  imageUrl: null,
  offerType: 'announcement',
  discountValue: null,
  terms: null,
  startsAt: null,
  endsAt: null,
  distanceKm: null,
  coinDiscountRate: null,
  applicableItem: null,
  isCoinRedeemable: false,
);

const _categories = [
  MerchantCategory(id: 1, name: 'Bakery, Sweets and Confectionery', slug: 'bakery'),
  MerchantCategory(id: 2, name: 'Textiles', slug: 'textiles'),
  MerchantCategory(id: 3, name: 'Electronics', slug: 'electronics'),
];

Widget _wrap(_FakeOffersRepository repository) {
  return ProviderScope(
    overrides: [
      offersRepositoryProvider.overrideWithValue(repository),
      merchantCategoriesProvider.overrideWith((ref) async => _categories),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const OffersListScreen()),
  );
}

void main() {
  testWidgets('Offers renders tabs, categories, the count and worst-case cards without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeOffersRepository()),
      verify: (tester, size) async {
        expect(find.text('All offers'), findsOneWidget);
        expect(find.text('Ending this week'), findsOneWidget);
        expect(find.text('Textiles'), findsOneWidget);
        expect(find.text('3 offers to explore'), findsOneWidget);
        expect(find.text('TOWN COIN'), findsOneWidget);
        expect(find.text('Claim offer'), findsOneWidget);

        // The third card is an announcement: no discount, no end date.
        final feed = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('Onam collection now in store'), feed, const Offset(0, -250));
        expect(find.text('Special offer'), findsOneWidget);
      },
    );
  });

  testWidgets('tabs and categories filter through the API, and a second tap clears the category', (tester) async {
    final repository = _FakeOffersRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.calls.last, (page: 1, categoryId: null, expiringWithinDays: null));

    await tester.tap(find.text('Ending this week'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (page: 1, categoryId: null, expiringWithinDays: 7));

    await tester.tap(find.text('Textiles'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (page: 1, categoryId: 2, expiringWithinDays: 7));
    expect(find.text('Live deals from Textiles shops'), findsOneWidget);

    await tester.tap(find.text('Textiles'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (page: 1, categoryId: null, expiringWithinDays: 7));
  });
}
