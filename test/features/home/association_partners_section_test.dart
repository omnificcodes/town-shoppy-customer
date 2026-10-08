import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/home/presentation/widgets/association_partners_section.dart';
import 'package:customer/features/merchants/application/associations_provider.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/association_merchants_screen.dart';
import 'package:customer/features/wallet/application/wallet_controller.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_favorites_repository.dart';

Merchant _merchant(int id, String name) => Merchant(
  id: id,
  name: name,
  description: null,
  logoUrl: null,
  websiteUrl: null,
  contactMobileNumber: null,
  socialLinks: null,
  discountRate: 10,
  acceptsTownCoin: true,
  category: null,
  association: null,
  branch: null,
);

/// Records which association each list request asked for.
class _FakeMerchantsRepository implements MerchantsRepository {
  final List<int?> associationIdsRequested = [];

  @override
  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    int? associationId,
    bool? acceptsTownCoin,
    bool? featured,
    String? search,
  }) async {
    associationIdsRequested.add(associationId);
    final items = [_merchant(11, 'Kairaly Bakers'), _merchant(12, 'Sree Textiles')];
    return OffsetPage(items: items, currentPage: 1, lastPage: 1, total: items.length);
  }

  @override
  Future<Merchant> show(int id) async => throw UnimplementedError();

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => throw UnimplementedError();

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    double? radiusKm,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

class _FixedWallet extends WalletController {
  @override
  Future<SilverWalletBalance> build() async => const SilverWalletBalance(
    balance: 340,
    universalBalance: 300,
    shopExclusiveBalance: 40,
    shopExclusiveBreakdown: [
      ShopExclusiveBreakdownEntry(
        merchantId: 11,
        merchantName: 'Kairaly Bakers',
        balance: 40,
        balanceInrEquivalent: 40,
        expiresAt: null,
      ),
    ],
    balanceInrEquivalent: 340,
    updatedAt: null,
  );
}

Widget _wrap(_FakeMerchantsRepository merchants) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: SingleChildScrollView(child: AssociationPartnersSection())),
      ),
      GoRoute(
        path: '/associations/:id',
        builder: (context, state) => AssociationMerchantsScreen(associationId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      associationsProvider.overrideWith(
        (ref) async => const [
          // A one-word name: the tile used to show only its initial ("V").
          AssociationRef(
            id: 7,
            name: 'Vyaparisamithi',
            slug: 'vyaparisamithi',
            town: TownRef(id: 1, name: 'Kollam', slug: 'kollam', stateRegion: null),
          ),
        ],
      ),
      merchantsRepositoryProvider.overrideWithValue(merchants),
      favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      walletControllerProvider.overrideWith(_FixedWallet.new),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('a tile shows the full association name and opens the list of its shops', (tester) async {
    final merchants = _FakeMerchantsRepository();
    await tester.pumpWidget(_wrap(merchants));
    await tester.pumpAndSettle();

    expect(find.text('Vyaparisamithi'), findsOneWidget);

    await tester.tap(find.text('Vyaparisamithi'));
    await tester.pumpAndSettle();

    expect(merchants.associationIdsRequested, [7]);
    expect(find.text('2 SHOPS'), findsOneWidget);
    expect(find.text('Kairaly Bakers'), findsOneWidget);
    expect(find.text('Sree Textiles'), findsOneWidget);
    // Coins locked to one shop show on that shop's card only.
    expect(find.text('40'), findsOneWidget);
  });
}
