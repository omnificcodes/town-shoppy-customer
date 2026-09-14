import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../coupons/application/coupons_list_controller.dart';
import '../../merchants/application/associations_provider.dart';
import '../../merchants/application/featured_merchants_provider.dart';
import '../../merchants/application/merchant_categories_provider.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../../offers/application/trending_offers_provider.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/home_nearby_controller.dart';
import 'widgets/association_partners_section.dart';
import 'widgets/best_offers_section.dart';
import 'widgets/category_grid.dart';
import 'widgets/featured_shops_section.dart';
import 'widgets/home_drawer.dart';
import 'widgets/home_header.dart';
import 'widgets/home_hero_banner.dart';
import 'widgets/home_stats_row.dart';
import 'widgets/nearby_stores_section.dart';

/// The customer's landing screen, following the Google Stitch redesign:
/// greeting, three quick stats, a promo hero, association partners,
/// categories, shops near you, featured shops, then offers near you.
///
/// Every section reads real data and hides itself when it has nothing to
/// show. Stitch's Royal Partners and Gift Partners sections are absent on
/// purpose: nothing in the backend defines either.
///
/// The old wallet card, recent purchases and "More" links left Home with
/// this redesign. Nothing became unreachable: the Town Coins and Coupons
/// stats open the wallet and coupons, and the drawer still lists purchases,
/// redemptions and every other destination they linked to.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final name = authState is AuthAuthenticated ? authState.account.customerProfile?.name : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(couponCountsProvider)
                    ..invalidate(associationsProvider)
                    ..invalidate(merchantCategoriesProvider)
                    ..invalidate(homeNearbyMerchantsProvider)
                    ..invalidate(featuredMerchantsProvider)
                    ..invalidate(trendingOffersProvider)
                    ..invalidate(unreadNotificationCountProvider);
                  await ref.read(walletControllerProvider.notifier).refresh();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl),
                  children: [
                    _Greeting(name: name),
                    const SizedBox(height: AppSpacing.md),
                    const HomeStatsRow(),
                    const SizedBox(height: AppSpacing.md),
                    const HomeHeroBanner(),
                    const AssociationPartnersSection(),
                    const CategoryGrid(),
                    const NearbyStoresSection(),
                    const FeaturedShopsSection(),
                    const BestOffersSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final firstName = name?.trim().split(RegExp(r'\s+')).first;
    final text = (firstName == null || firstName.isEmpty) ? period : '$period, $firstName';

    return Semantics(
      header: true,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.greeting),
    );
  }
}
