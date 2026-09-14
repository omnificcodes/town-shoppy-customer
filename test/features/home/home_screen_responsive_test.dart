import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/coupons/application/coupons_list_controller.dart';
import 'package:customer/features/home/application/home_location_controller.dart';
import 'package:customer/features/home/application/home_nearby_controller.dart';
import 'package:customer/features/home/presentation/home_screen.dart';
import 'package:customer/features/merchants/application/associations_provider.dart';
import 'package:customer/features/merchants/application/featured_merchants_provider.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/merchant_business_hours.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:customer/features/offers/application/trending_offers_provider.dart';
import 'package:customer/features/offers/data/models/offer.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/responsive_test_helper.dart';

/// Every fixture below is the realistic worst case for its slot: the
/// backend caps none of these lengths, and a balance or rupee value can run
/// to many digits. Home has to survive all of them at once at every
/// mandated viewport.
const _longName = 'Venkataramanujachandrasekaran Padmanabhaswamy Iyengar';
const _longMerchant = 'The Grand Downtown Corner Cafe and Bakery Emporium';

const _account = Account(
  id: 1,
  mobileNumber: '9990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['customer'],
  customerProfile: CustomerProfile(
    id: 1,
    name: _longName,
    dateOfBirth: null,
    anniversaryDate: null,
    socialLinks: null,
    referralCode: 'ABC123',
    status: 'active',
  ),
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _ReadyLocationController extends HomeLocationController {
  @override
  Future<HomeLocationState> build() async => const HomeLocationReady(
        latitude: 10.02,
        longitude: 76.31,
        label: 'Edappally, Ernakulam District, Kerala State',
      );
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => const SilverWalletBalance(
        balance: 1234567,
        universalBalance: 1234567,
        shopExclusiveBalance: 0,
        shopExclusiveBreakdown: [],
        balanceInrEquivalent: 123456.7,
        updatedAt: null,
      );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

Merchant _merchant(int id) {
  return Merchant(
    id: id,
    name: _longMerchant,
    description: null,
    logoUrl: null,
    websiteUrl: null,
    contactMobileNumber: null,
    socialLinks: null,
    discountRate: 12.5,
    acceptsTownCoin: true,
    category: const MerchantCategory(id: 1, name: 'Bakery, Sweets and Confectionery', slug: 'bakery'),
    association: null,
    branch: null,
    tagline: 'Fresh bakes every single morning since 1996, straight from our own ovens',
    businessHours: MerchantBusinessHours.tryParse({
      for (final day in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])
        day: {'open': '00:00', 'close': '00:00', 'closed': false},
    }),
  );
}

Offer _offer(int id, String title) {
  return Offer(
    id: id,
    merchantId: 1,
    merchantName: _longMerchant,
    merchantLogoUrl: null,
    title: title,
    description: null,
    imageUrl: null,
    offerType: 'percentage',
    discountValue: 25,
    terms: null,
    startsAt: null,
    endsAt: DateTime.now().add(const Duration(days: 3)),
    distanceKm: 0.8,
    coinDiscountRate: null,
    applicableItem: null,
    isCoinRedeemable: id.isEven,
  );
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      couponCountsProvider.overrideWith((ref) async => const CouponCounts(active: 98765, won: 3, expired: 12)),
      homeLocationControllerProvider.overrideWith(_ReadyLocationController.new),
      unreadNotificationCountProvider.overrideWith((ref) async => 3),
      associationsProvider.overrideWith(
        (ref) async => const [
          AssociationRef(
            id: 1,
            name: 'Kerala Vyapari Vyavasayi Ekopana Samithi',
            slug: 'kvves',
            town: TownRef(id: 1, name: 'Thiruvananthapuram Corporation Area', slug: 'tvm', stateRegion: null),
            shortCode: 'KVVES',
          ),
          AssociationRef(id: 2, name: 'Kerala Hotel and Restaurant Association', slug: 'khra', town: null),
        ],
      ),
      merchantCategoriesProvider.overrideWith(
        (ref) async => [
          for (var i = 1; i <= 12; i++) MerchantCategory(id: i, name: 'Category number $i with a long name', slug: 'c$i'),
        ],
      ),
      homeNearbyMerchantsProvider.overrideWith(
        (ref) async => [
          NearbyMerchant(
            merchant: _merchant(2),
            branch: const MerchantBranchRef(
              id: 1,
              name: 'Main branch',
              isPrimary: true,
              addressLine: null,
              locality: 'Edappally Toll Junction, near Lulu International Shopping Mall',
              city: 'Kochi',
              state: null,
              postalCode: null,
              country: null,
              latitude: null,
              longitude: null,
              distanceKm: 0.34,
            ),
            distanceKm: 0.34,
          ),
        ],
      ),
      featuredMerchantsProvider.overrideWith((ref) async => [_merchant(3), _merchant(4)]),
      trendingOffersProvider.overrideWith(
        (ref) async => [
          _offer(1, 'Weekend feast: flat 25% off across every cafe and bakery counter in town'),
          _offer(2, 'Buy one get one on all festival sweets and savoury hampers'),
          _offer(3, 'Double Town Coins on your next grocery bill above two thousand rupees'),
        ],
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
  );
}

void main() {
  testWidgets('Home renders every section without overflow at every mandated viewport, with worst-case content', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.textContaining('Good '), findsOneWidget);
        expect(find.text('1234567'), findsOneWidget);
        expect(find.text('98765'), findsOneWidget);

        // The nearest offer leads as the hero, so it isn't repeated below.
        expect(find.text('Weekend feast: flat 25% off across every cafe and bakery counter in town'), findsOneWidget);

        final page = find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(ListView)).first;

        for (final heading in [
          'Association Partners',
          'Browse by Category',
          'Find Stores Near You',
          'Featured Shops',
          'Best Offers Near You',
        ]) {
          await tester.dragUntilVisible(find.text(heading), page, const Offset(0, -200));
          expect(find.text(heading), findsOneWidget, reason: '$heading should be reachable at $size');
        }
      },
    );
  });
}
