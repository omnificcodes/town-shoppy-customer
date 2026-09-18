import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../../shared/widgets/notification_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../merchants/application/merchant_categories_provider.dart';
import '../../merchants/presentation/category_visual.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../application/wallet_controller.dart';
import '../application/wallet_transactions_controller.dart';
import '../data/models/silver_wallet_balance.dart';
import 'wallet_ledger_tile.dart';

/// Coin Economy V2 (coin-economy-v2.md §10) -- a Shop-Exclusive (TU) Coin
/// lot within this many days of expiring surfaces the in-app banner below;
/// the WhatsApp reminder is a separate, server-scheduled job with its own
/// (non-public) threshold setting, so this is only a display convenience
/// and need not match it exactly.
const _expiryBannerThresholdDays = 7;

/// The Town Coin wallet, following the Google Stitch redesign: a warm hero
/// with the balance, the store-locked / universal split, where to spend,
/// each shop's locked coins, a scan-to-redeem action, then the full ledger.
///
/// Every figure is the live `GET /town-coins/wallet` response. Stitch's
/// "Total lifetime savings", PRO badge, per-category distances and store
/// counts, and per-shop discount chips are absent on purpose: the backend
/// records none of them. The second hero tile states the coin's real value
/// instead, and that coins are a discount, never cash.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const _loadMoreThreshold = 300.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(walletTransactionsControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(walletTransactionsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(merchantCategoriesProvider);
                  await ref.read(walletControllerProvider.notifier).refresh();
                  await ref.read(walletTransactionsControllerProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
                      sliver: SliverList.list(
                        children: const [
                          _HeroCard(),
                          SizedBox(height: AppSpacing.section),
                          _CoinSplitSection(),
                          _SpendSection(),
                          _StoreLockedSection(),
                          SizedBox(height: AppSpacing.section),
                          _ScanToRedeemButton(),
                          SizedBox(height: AppSpacing.md),
                          _MoreLinks(),
                          SizedBox(height: AppSpacing.section),
                          SectionHeader(title: 'Transaction history'),
                          SizedBox(height: AppSpacing.smd),
                        ],
                      ),
                    ),
                    ...transactions.when(
                      loading: () => [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                          sliver: SliverList.separated(
                            itemCount: 3,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, _) => const LoadingSkeletonCard(),
                          ),
                        ),
                      ],
                      error: (error, _) => [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                          sliver: SliverToBoxAdapter(
                            child: ErrorState(
                              compact: true,
                              error: error is AppException ? error : const UnknownAppException(),
                              onRetry: () => ref.read(walletTransactionsControllerProvider.notifier).refresh(),
                            ),
                          ),
                        ),
                      ],
                      data: (data) => [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                          sliver: SliverList.list(
                            children: [
                              if (data.items.isEmpty)
                                const EmptyState(
                                  compact: true,
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No activity yet',
                                  message:
                                      'Coins you earn from purchases, and coins you spend on redemptions, will show up here.',
                                ),
                              for (final entry in data.items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: WalletLedgerTile(entry: entry),
                                ),
                              if (data.hasMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                                  child: Center(
                                    child: CircularProgressIndicator(semanticsLabel: 'Loading more activity'),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                                  child: NavLinkCard(
                                    icon: Icons.storefront_rounded,
                                    title: 'Earn more Town Coin',
                                    subtitle: 'Find participating merchants near you',
                                    onTap: () => context.push('/merchants'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(header: true, child: Text('Wallet', style: AppTypography.sectionTitle)),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: NotificationBadge(count: unreadCount, child: const Icon(Icons.notifications_outlined)),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }
}

/// The warm hero: who is signed in, their coins, and what a coin is worth.
class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;
    final name = account?.customerProfile?.name?.trim();
    final firstName = name == null || name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
    final wallet = ref.watch(walletControllerProvider);
    final isRefreshing = ref.watch(walletRefreshingProvider);
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: AppGradients.promoHero,
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.xl,
              bottom: -AppSpacing.xl,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.14), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: AppSpacing.lg,
              top: AppSpacing.xs,
              child: ExcludeSemantics(
                child: Icon(Icons.currency_rupee_rounded, size: 84, color: AppColors.onScrim.withValues(alpha: 0.08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: firstName == null ? 'Profile info' : 'Hello, $firstName. Profile info',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      onTap: () => context.go('/profile'),
                      child: Row(
                        children: [
                          Container(
                            width: AppSize.controlLg,
                            height: AppSize.controlLg,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppGradients.warmWash,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.onScrim.withValues(alpha: 0.6), width: 2),
                            ),
                            child: Text(
                              _initials(name, account?.mobileNumber ?? ''),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.orangeDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.smd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  firstName == null ? 'Hello!' : 'Hello, $firstName!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.onScrim,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Profile info',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: AppIconSize.sm,
                                      color: AppColors.onScrimMuted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isRefreshing)
                            const Padding(
                              padding: EdgeInsets.only(right: AppSpacing.sm),
                              child: SizedBox(
                                width: AppIconSize.xs,
                                height: AppIconSize.xs,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onScrim),
                              ),
                            ),
                          Container(
                            width: AppSize.controlSm,
                            height: AppSize.controlSm,
                            decoration: BoxDecoration(
                              color: AppColors.onScrim.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.onScrim.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.chevron_right_rounded, color: AppColors.onScrim),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
                    child: Divider(height: 1, color: AppColors.onScrim.withValues(alpha: 0.2)),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HeroTile(
                            label: 'Your Town Coins',
                            chip: switch (wallet) {
                              AsyncData(:final value) => '≈ ₹${_rupees(value.balanceInrEquivalent)}',
                              _ => null,
                            },
                            badge: const _Badge(
                              icon: Icons.toll_rounded,
                              background: AppColors.yellow,
                              foreground: AppColors.onYellow,
                            ),
                            value: switch (wallet) {
                              AsyncData(:final value) => '${value.balance}',
                              AsyncError() => '—',
                              _ => null,
                            },
                            unit: 'coins',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: _HeroTile(
                            label: 'Coin value',
                            badge: _Badge(
                              icon: Icons.currency_rupee_rounded,
                              background: AppColors.successBg,
                              foreground: AppColors.success,
                            ),
                            value: '10 = ₹1',
                            caption: 'A discount, never cash',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.label, required this.badge, required this.value, this.unit, this.chip, this.caption});

  final String label;
  final Widget badge;
  final String? value;
  final String? unit;
  final String? chip;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final shownValue = value;
    final shownChip = chip;
    final shownUnit = unit;
    final shownCaption = caption;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scrim.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.onScrim.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.smd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(label, style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted)),
                ),
                if (shownChip != null) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.onScrim.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 1),
                        child: Text(
                          shownChip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.badgeLabel.copyWith(color: AppColors.onScrim),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                badge,
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: shownValue == null
                      ? const Align(alignment: Alignment.centerLeft, child: LoadingSkeleton(width: 64, height: 22))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                shownValue,
                                style: AppTypography.numericFinancialMedium.copyWith(
                                  color: AppColors.onScrim,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (shownUnit != null) ...[
                                const SizedBox(width: AppSpacing.xxs),
                                Text(shownUnit, style: AppTypography.caption.copyWith(color: AppColors.goldLight)),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (shownCaption != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(shownCaption, style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.background, required this.foreground});

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppIconSize.lg,
      height: AppIconSize.lg,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: AppIconSize.sm, color: foreground),
    );
  }
}

/// A small uppercase heading with a coloured dot, and an optional trailing
/// chip or link.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.dot, this.trailing});

  final String label;
  final Color dot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shownTrailing = trailing;

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: AppTypography.overline.copyWith(color: AppColors.textPrimary, letterSpacing: 0.8),
            ),
          ),
        ),
        ?shownTrailing,
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        child: Text(label, style: AppTypography.badgeLabel.copyWith(color: AppColors.textSecondary)),
      ),
    );
  }
}

/// Coin Economy V2 (coin-economy-v2.md §1/§1.5) -- the store-locked (TU) and
/// universal (T) pools side by side, their real share of the balance, and a
/// banner for any locked coins close to expiring.
class _CoinSplitSection extends ConsumerWidget {
  const _CoinSplitSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final value = switch (wallet) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (value == null) {
      if (wallet.hasError) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.section),
        child: LoadingSkeleton(height: 150, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      );
    }

    final total = value.shopExclusiveBalance + value.universalBalance;
    final lockedPercent = total == 0 ? 0 : (value.shopExclusiveBalance * 100 / total).round();
    final universalPercent = total == 0 ? 0 : 100 - lockedPercent;

    final soonExpiring = value.shopExclusiveBreakdown.where((row) {
      final expiresAt = row.expiresAt;
      if (expiresAt == null) return false;
      return expiresAt.difference(DateTime.now()).inDays <= _expiryBannerThresholdDays;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            label: 'WHERE YOUR COINS WORK',
            dot: AppColors.orangeDeep,
            trailing: _CountChip(label: '${value.balance} total'),
          ),
          const SizedBox(height: AppSpacing.smd),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PoolCard(
                    icon: Icons.lock_rounded,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.orange, AppColors.orangeDeep],
                        stops: [0, 0.45],
                      ),
                    ),
                    percent: lockedPercent,
                    label: 'STORE-LOCKED',
                    coins: value.shopExclusiveBalance,
                    hint: 'Spend only at the shop you earned them',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PoolCard(
                    icon: Icons.public_rounded,
                    decoration: const BoxDecoration(color: AppColors.success),
                    percent: universalPercent,
                    label: 'UNIVERSAL',
                    coins: value.universalBalance,
                    hint: 'Spend at any Town Coin shop',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SplitBar(locked: value.shopExclusiveBalance, universal: value.universalBalance),
          if (soonExpiring.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InfoBox(
              tone: AppTone.pending,
              icon: Icons.hourglass_bottom_rounded,
              title: 'Store-locked coins expiring soon',
              message: soonExpiring.length == 1
                  ? '${soonExpiring.first.balance} coins at ${soonExpiring.first.merchantName} expire ${_expiryPhrase(soonExpiring.first.expiresAt!)}. Spend them there before then.'
                  : 'You have store-locked coins at ${soonExpiring.length} shops expiring soon. Spend them there before they expire.',
            ),
          ],
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({
    required this.icon,
    required this.decoration,
    required this.percent,
    required this.label,
    required this.coins,
    required this.hint,
  });

  final IconData icon;
  final BoxDecoration decoration;
  final int percent;
  final String label;
  final int coins;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      label: '$label coins: $coins, $percent percent of your balance. $hint',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: decoration.copyWith(borderRadius: radius, boxShadow: AppElevation.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSize.avatarSm,
                    height: AppSize.avatarSm,
                    decoration: BoxDecoration(
                      color: AppColors.onScrim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    ),
                    child: Icon(icon, size: AppIconSize.md, color: AppColors.onScrim),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.onScrim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
                      child: Text('$percent%', style: AppTypography.badgeLabel.copyWith(color: AppColors.onScrim)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smd),
              Text(label, style: AppTypography.overline.copyWith(color: AppColors.onScrimMuted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$coins coins',
                  style: AppTypography.numericFinancialSmall.copyWith(
                    color: AppColors.onScrim,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(hint, style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.locked, required this.universal});

  final int locked;
  final int universal;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                // Childless ColoredBoxes size to their smallest constraint, so
                // the bar needs tight constraints: full width, and a row that
                // stretches its segments to the bar's height.
                child: SizedBox(
                  height: 8,
                  width: double.infinity,
                  child: locked + universal == 0
                      ? const ColoredBox(color: AppColors.silverLight)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (locked > 0)
                              Expanded(
                                flex: locked,
                                child: const ColoredBox(color: AppColors.orange),
                              ),
                            if (universal > 0)
                              Expanded(
                                flex: universal,
                                child: const ColoredBox(color: AppColors.success),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(child: Text('$locked store-locked', style: AppTypography.caption)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('$universal universal', textAlign: TextAlign.end, style: AppTypography.caption),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where universal coins go: the first four merchant categories, and every
/// shop that currently accepts Town Coin behind "Explore all".
class _SpendSection extends ConsumerWidget {
  const _SpendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider).value;
    if (categories == null || categories.isEmpty) return const SizedBox.shrink();

    final shown = categories.take(4).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            label: 'WHERE TO SPEND',
            dot: AppColors.success,
            trailing: TextButton(
              onPressed: () => context.push('/redeem'),
              style: TextButton.styleFrom(foregroundColor: AppColors.orangeDeep, visualDensity: VisualDensity.compact),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Explore all'),
                  Icon(Icons.chevron_right_rounded, size: AppIconSize.sm),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i < shown.length
                      ? _CategoryTile(id: shown[i].id, name: shown[i].name, slug: shown[i].slug)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.forCategory(name: name, slug: slug);
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: '$name shops',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/merchants', extra: id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.smd),
              child: Column(
                children: [
                  Container(
                    width: AppSize.controlLg - AppSpacing.xs,
                    height: AppSize.controlLg - AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                      border: Border.all(color: visual.color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: AppIconSize.md),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.badgeLabel.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Each shop holding store-locked coins, how many, what they are worth and
/// when the nearest lot expires, with a way to that shop.
class _StoreLockedSection extends ConsumerWidget {
  const _StoreLockedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final rows = switch (wallet) {
      AsyncData(:final value) => value.shopExclusiveBreakdown.where((row) => row.balance > 0).toList(),
      _ => const <ShopExclusiveBreakdownEntry>[],
    };
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          label: 'MY STORE-LOCKED COINS',
          dot: AppColors.gold,
          trailing: _CountChip(label: rows.length == 1 ? '1 shop' : '${rows.length} shops'),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _StoreLockedRow(row: rows[i]),
        ],
      ],
    );
  }
}

class _StoreLockedRow extends StatelessWidget {
  const _StoreLockedRow({required this.row});

  final ShopExclusiveBreakdownEntry row;

  @override
  Widget build(BuildContext context) {
    final expiresAt = row.expiresAt;
    final expiringSoon = expiresAt != null && expiresAt.difference(DateTime.now()).inDays <= _expiryBannerThresholdDays;

    return Semantics(
      container: true,
      label: [
        '${row.balance} store-locked coins at ${row.merchantName}',
        'worth about ${_rupees(row.balanceInrEquivalent)} rupees',
        if (expiresAt != null) 'expire ${_shortDate(expiresAt)}',
      ].join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
          boxShadow: AppElevation.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Row(
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.goldDark, size: AppIconSize.md),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.merchantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${row.balance} coins',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          Text('≈ ₹${_rupees(row.balanceInrEquivalent)}', style: AppTypography.caption),
                          if (expiresAt != null)
                            Text(
                              'Expires ${_shortDate(expiresAt)}',
                              style: AppTypography.caption.copyWith(
                                color: expiringSoon ? AppColors.pending : AppColors.textSecondary,
                                fontWeight: expiringSoon ? FontWeight.w700 : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.successBg,
                shape: StadiumBorder(side: BorderSide(color: AppColors.success.withValues(alpha: 0.3))),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.push('/merchants/${row.merchantId}'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Visit',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scanning a shop's counter QR is how coins come off a bill.
class _ScanToRedeemButton extends StatelessWidget {
  const _ScanToRedeemButton();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: 'Scan QR to redeem coins',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.floating),
        child: Material(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppGradients.promoHero),
            child: InkWell(
              onTap: () => context.push('/purchases/scan'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.controlLg + AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: AppIconSize.xl,
                        height: AppIconSize.xl,
                        decoration: BoxDecoration(
                          color: AppColors.onScrim.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: AppIconSize.md,
                          color: AppColors.onScrim,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'SCAN QR TO REDEEM COINS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.onScrim,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How coins work, and the two histories that live outside this ledger.
class _MoreLinks extends StatelessWidget {
  const _MoreLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _LinkPill(icon: Icons.help_outline_rounded, label: 'How it works', onTap: () => _showHowItWorks(context)),
        _LinkPill(icon: Icons.history_rounded, label: 'Redemptions', onTap: () => context.push('/redemptions')),
        _LinkPill(
          icon: Icons.local_offer_outlined,
          label: 'Offer redemptions',
          onTap: () => context.push('/offer-redemptions'),
        ),
      ],
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        // Scrolls so a short viewport or large text scale never clips the
        // last step.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How Town Coins work', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              const _HowItWorksStep(
                number: '1',
                title: 'Earn coins on purchases',
                description:
                    'Shop at a participating merchant and they record your purchase — coins land in your wallet.',
              ),
              const _HowItWorksStep(
                number: '2',
                title: 'Know which coins go where',
                description:
                    'Universal coins work at any Town Coin shop. Store-locked coins work only at the shop you earned them.',
              ),
              const _HowItWorksStep(
                number: '3',
                title: 'Redeem for a discount',
                description:
                    'Scan the shop’s QR at the counter to take coins off your bill. Coins are a discount, never cash.',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Got it',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.controlSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.sm, color: AppColors.orangeDeep),
                const SizedBox(width: AppSpacing.xs),
                Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({required this.number, required this.title, required this.description});

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppIconSize.xl,
            height: AppIconSize.xl,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            child: Text(number, style: AppTypography.badgeLabel.copyWith(color: AppColors.onOrange)),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String? name, String mobile) {
  if (name != null && name.isNotEmpty) {
    final parts = name.split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
  return mobile.length >= 2 ? mobile.substring(mobile.length - 2) : '?';
}

String _rupees(double amount) =>
    amount.truncateToDouble() == amount ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _shortDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}

String _expiryPhrase(DateTime expiresAt) {
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}
