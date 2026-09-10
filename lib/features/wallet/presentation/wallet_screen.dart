import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../../shared/widgets/notification_badge.dart';
import '../../../shared/widgets/section_header.dart';
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

/// The full Town Coin wallet -- a large, trustworthy balance up top (same
/// silver visual language as Home's own wallet card, just bigger since
/// this screen's whole job is showing it) and the complete earn/spend
/// timeline below it. The backend `balance_cache` is always a live read
/// (never client-cached), so this screen is the authoritative place to see
/// exactly what the server currently thinks the balance is.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const _loadMoreThreshold = 200.0;

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
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return AppScaffold(
      title: 'Wallet',
      padded: false,
      actions: [
        IconButton(
          icon: NotificationBadge(count: unreadCount, child: const Icon(Icons.notifications_outlined)),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletControllerProvider.notifier).refresh();
          await ref.read(walletTransactionsControllerProvider.notifier).refresh();
        },
        child: transactions.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: const [
              _BalanceHero(),
              SizedBox(height: AppSpacing.lg),
              LoadingSkeletonCard(),
              SizedBox(height: AppSpacing.sm),
              LoadingSkeletonCard(),
              SizedBox(height: AppSpacing.sm),
              LoadingSkeletonCard(),
            ],
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.read(walletTransactionsControllerProvider.notifier).refresh(),
          ),
          data: (data) {
            // Static leading content (balance hero, redeem CTA, quick
            // actions, section heading, and -- when there is no history yet
            // -- the empty state) followed by the paginated ledger. Built
            // via ListView.builder's index dispatch so a long transaction
            // history isn't eagerly built off-screen.
            final headerWidgets = <Widget>[
              const _BalanceHero(),
              const SizedBox(height: AppSpacing.md),
              const _CoinSplitSection(),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Redeem your coins',
                size: AppButtonSize.lg,
                icon: Icons.qr_code_2_rounded,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.push('/redeem'),
              ),
              const SizedBox(height: AppSpacing.section),
              const _QuickActionsGrid(),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Transaction history'),
              const SizedBox(height: AppSpacing.smd),
              if (data.items.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.receipt_long_outlined,
                  title: 'No activity yet',
                  message: 'Coins you earn from purchases, and coins you spend on redemptions, will show up here.',
                ),
            ];

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: headerWidgets.length + data.items.length + (data.hasMore ? 1 : 0) + 1,
              itemBuilder: (context, index) {
                if (index < headerWidgets.length) return headerWidgets[index];

                final itemIndex = index - headerWidgets.length;
                if (itemIndex >= data.items.length) {
                  // The very last slot: a trailing loading spinner while
                  // more pages are still coming, or -- once hasMore is
                  // false -- the "earn more" link, so it reads as the
                  // natural end of the timeline.
                  if (data.hasMore && itemIndex == data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: NavLinkCard(
                      icon: Icons.storefront_rounded,
                      title: 'Earn more Town Coin',
                      subtitle: 'Find participating merchants near you',
                      onTap: () => context.push('/merchants'),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: WalletLedgerTile(entry: data.items[itemIndex]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BalanceHero extends ConsumerWidget {
  const _BalanceHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final isRefreshing = ref.watch(walletRefreshingProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.orangeTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Stack(
        children: [
          const Positioned(right: -AppSpacing.sm, top: AppSpacing.xs, child: _CoinStackGlyph()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSize.avatarMd,
                    height: AppSize.avatarMd,
                    decoration: BoxDecoration(
                      color: AppColors.orangeTintStrong,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.savings_rounded, color: AppColors.orange, size: AppIconSize.md),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Town Coins', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: AppIconSize.xs,
                      height: AppIconSize.xs,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldDark),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              switch (wallet) {
                AsyncData(:final value) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          '${value.balance}',
                          style: AppTypography.numericFinancialLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('coins', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                AsyncError() => Text('Unable to load', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                _ => const LoadingSkeleton(width: 140, height: 40),
              },
              if (wallet case AsyncData(:final value))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    '≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coin Economy V2 (coin-economy-v2.md §1/§1.5) -- the Universal/
/// Shop-Exclusive split, collapsed by default (most customers never need
/// it: the FIFO priority already spends the right coin automatically). A
/// tap expands the per-merchant breakdown, and any lot expiring soon gets
/// a banner right below it. Renders nothing at all for a wallet with no
/// Shop-Exclusive coins, so a pre-V2-style customer never sees an empty
/// "0 Shop-Exclusive" line cluttering the screen.
class _CoinSplitSection extends ConsumerStatefulWidget {
  const _CoinSplitSection();

  @override
  ConsumerState<_CoinSplitSection> createState() => _CoinSplitSectionState();
}

class _CoinSplitSectionState extends ConsumerState<_CoinSplitSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletControllerProvider);
    final value = switch (wallet) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (value == null || !value.hasShopExclusiveCoins) return const SizedBox.shrink();

    final soonExpiring = value.shopExclusiveBreakdown.where((row) {
      final expiresAt = row.expiresAt;
      if (expiresAt == null) return false;
      return expiresAt.difference(DateTime.now()).inDays <= _expiryBannerThresholdDays;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Coin balance breakdown, ${value.universalBalance} universal, ${value.shopExclusiveBalance} shop-exclusive',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SplitFigure(label: 'Universal', value: value.universalBalance, hint: 'Usable at any merchant'),
                      ),
                      Container(width: 1, height: 36, color: AppColors.border),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _SplitFigure(
                          label: 'Shop-Exclusive',
                          value: value.shopExclusiveBalance,
                          hint: 'Locked to where you earned it',
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    for (final row in value.shopExclusiveBreakdown) _ShopExclusiveRow(row: row),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (soonExpiring.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          InfoBox(
            tone: AppTone.pending,
            icon: Icons.hourglass_bottom_rounded,
            title: 'Shop-Exclusive coins expiring soon',
            message: soonExpiring.length == 1
                ? '${soonExpiring.first.balance} coins at ${soonExpiring.first.merchantName} expire ${_expiryPhrase(soonExpiring.first.expiresAt!)}. Spend them there before then.'
                : 'You have Shop-Exclusive coins at ${soonExpiring.length} merchants expiring soon. Spend them there before they expire.',
          ),
        ],
      ],
    );
  }

  String _expiryPhrase(DateTime expiresAt) {
    final days = expiresAt.difference(DateTime.now()).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

class _SplitFigure extends StatelessWidget {
  const _SplitFigure({required this.label, required this.value, required this.hint});

  final String label;
  final int value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text('$value coins', style: AppTypography.numericFinancialSmall),
        Text(hint, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ShopExclusiveRow extends StatelessWidget {
  const _ShopExclusiveRow({required this.row});

  final ShopExclusiveBreakdownEntry row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.merchantName, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (row.expiresAt != null)
                  Text(
                    'Expires ${_shortDate(row.expiresAt!)}',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('${row.balance}', style: AppTypography.numericFinancialSmall.copyWith(color: AppColors.goldDark)),
        ],
      ),
    );
  }

  String _shortDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

/// A decorative stacked-coin motif -- no illustration asset exists for this
/// (see design-principles.md's zero-extra-asset stance), so this is built
/// entirely from layered circles + the same "T" token mark used on the
/// wallet's own icon elsewhere, in the gold tones reserved for Town Coin
/// specifically (never the brand orange, so the coin itself still reads as
/// its own currency even though the card behind it is warm).
class _CoinStackGlyph extends StatelessWidget {
  const _CoinStackGlyph();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 76,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 16, child: _Coin(size: 52, color: AppColors.gold)),
            Positioned(top: 6, child: _Coin(size: 52, color: AppColors.goldDark)),
            Positioned(right: 4, top: 0, child: Icon(Icons.auto_awesome_rounded, size: AppIconSize.xs, color: AppColors.orange)),
          ],
        ),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Decorative glyph on a fixed-size coin: pinned text scale so a large
    // system font can't push the "T" outside its circle.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: Text(
          'T',
          style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.surface, fontSize: size * 0.4, height: 1),
        ),
      ),
    );
  }
}

/// Four secondary actions as a grid that reflows to two columns under
/// 360dp — labels wrap naturally instead of carrying hard-coded line
/// breaks that overflowed at 320dp.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const _narrowBreakpoint = 360.0;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _QuickAction(
        icon: Icons.description_outlined,
        iconColor: AppColors.orange,
        label: 'How it works',
        onTap: () => _showHowItWorks(context),
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        iconColor: AppColors.success,
        label: 'Redemption history',
        onTap: () => context.push('/redemptions'),
      ),
      _QuickAction(
        icon: Icons.local_offer_outlined,
        iconColor: AppColors.orange,
        label: 'Offer redemptions',
        onTap: () => context.push('/offer-redemptions'),
      ),
      _QuickAction(
        icon: Icons.verified_user_outlined,
        iconColor: AppColors.info,
        label: 'Terms & conditions',
        onTap: () => _showComingSoon(context, 'Terms & Conditions'),
      ),
      _QuickAction(
        icon: Icons.support_agent_rounded,
        iconColor: AppColors.crimson,
        label: 'Help & support',
        onTap: () => _showComingSoon(context, 'Help & Support'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < _narrowBreakpoint ? 2 : 4;
        final rows = <Widget>[];
        for (var i = 0; i < actions.length; i += columns) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + columns; j++)
                  Expanded(child: j < actions.length ? actions[j] : const SizedBox.shrink()),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: AppSpacing.sm),
              rows[r],
            ],
          ],
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
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
                description: 'Shop at a participating merchant and they record your purchase — coins land in your wallet.',
              ),
              const _HowItWorksStep(
                number: '2',
                title: 'Watch your balance grow',
                description: 'Every coin you earn is visible here, with a full history of how you got it.',
              ),
              const _HowItWorksStep(
                number: '3',
                title: 'Redeem for a discount',
                description: 'Show your redemption code at any Town Coin-accepting merchant to take coins off your bill.',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Got it', variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
            ],
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.iconColor, required this.label, required this.onTap});

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Column(
            children: [
              Container(
                width: AppSpacing.touchTarget,
                height: AppSpacing.touchTarget,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: AppIconSize.lg),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
