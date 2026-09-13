import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../merchants/data/models/merchant.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../application/merchant_wallet_controller.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// The business's own coins. Blue is spendable at other Town Shoppy
/// merchants; Red is a running record. Gold is the merchant-wallet
/// identity (design-principles.md "Silver vs. Gold"), so the two balance
/// cards are the one place Business mode paints with it.
class MerchantWalletScreen extends ConsumerWidget {
  const MerchantWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(merchantWalletProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BusinessPageHeader(
              title: 'Wallet',
              subtitle: 'Coins your business has earned from customer redemptions',
              leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.page),
            sliver: SliverList.list(
              children: [
                wallet.when(
                  loading: () => const Column(children: [LoadingSkeleton(height: 140, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg))), SizedBox(height: AppSpacing.smd), LoadingSkeleton(height: 110, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)))]),
                  error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load your wallet.', onRetry: () => ref.invalidate(merchantWalletProvider)),
                  data: (w) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BalanceCard(
                        title: 'Blue Coin',
                        subtitle: 'Spendable at other Town Shoppy merchants',
                        coins: w.blueBalance,
                        inr: w.blueInr,
                        icon: Icons.toll_rounded,
                        colors: const [Color(0xFF1E3A8A), Color(0xFF3B5BA9)],
                      ),
                      const SizedBox(height: AppSpacing.smd),
                      _BalanceCard(
                        title: 'Red Coin',
                        subtitle: 'Recorded for a future feature — not spendable yet',
                        coins: w.redBalance,
                        inr: w.redInr,
                        icon: Icons.savings_rounded,
                        colors: const [AppColors.businessInk, AppColors.crimson],
                        muted: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Spend Blue Coin at another merchant',
                        icon: Icons.send_rounded,
                        size: AppButtonSize.lg,
                        onPressed: w.blueBalance > 0 ? () => _openSpendSheet(context, ref, w.blueBalance) : null,
                      ),
                      if (w.blueBalance <= 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text('Blue Coin arrives when customers redeem Town Coin at your shop.', style: AppTypography.caption, textAlign: TextAlign.center),
                      ],
                      if (w.updatedAt != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Updated ${formatDateTime(w.updatedAt!)}', style: AppTypography.caption, textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Text('How it works', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.smd),
                const _HowItWorks(icon: Icons.storefront_rounded, title: 'Earn on every redemption', body: 'When a customer spends Town Coin at your counter, your business receives the full coin value as Blue Coin — and the same again as Red Coin.'),
                const SizedBox(height: AppSpacing.sm),
                const _HowItWorks(icon: Icons.shopping_bag_rounded, title: 'Spend Blue Coin elsewhere', body: "Pay part of your own bill at another Town Shoppy merchant. The discount is capped by that merchant's discount rate and your balance. 10 coins = ₹1."),
                const SizedBox(height: AppSpacing.sm),
                const _HowItWorks(icon: Icons.workspace_premium_rounded, title: 'Subscription bonus', body: 'Every ₹500 of plan spend in a month adds bonus Blue and Red Coin to your wallet.'),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSpendSheet(BuildContext context, WidgetRef ref, int blueBalance) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _SpendBlueCoinSheet(blueBalance: blueBalance),
      ),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.coinsDebited} Blue Coin spent — ${formatMoney(result.discountAmount)} off at ${result.redeemingMerchantName ?? 'that merchant'}.')));
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.title, required this.subtitle, required this.coins, required this.inr, required this.icon, required this.colors, this.muted = false});

  final String title;
  final String subtitle;
  final int coins;
  final double inr;
  final IconData icon;
  final List<Color> colors;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$title: $coins coins, about ${formatMoney(inr)}. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTypography.overline.copyWith(color: AppColors.goldLight)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('$coins', style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.surface)),
                  Text('coins · ≈ ${formatMoney(inr)}', style: textTheme.bodyMedium?.copyWith(color: AppColors.surface.withValues(alpha: 0.85))),
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.surface.withValues(alpha: 0.75))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: muted ? 0.12 : 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.goldLight, size: AppIconSize.xl),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: const BoxDecoration(color: AppColors.goldLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.goldDark, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick a merchant (searched by name, Town Coin-accepting only), type the
/// bill, see the estimated discount, confirm. Settles immediately.
class _SpendBlueCoinSheet extends ConsumerStatefulWidget {
  const _SpendBlueCoinSheet({required this.blueBalance});

  final int blueBalance;

  @override
  ConsumerState<_SpendBlueCoinSheet> createState() => _SpendBlueCoinSheetState();
}

class _SpendBlueCoinSheetState extends ConsumerState<_SpendBlueCoinSheet> {
  final _query = TextEditingController();
  final _amount = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _query.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spendBlueCoinControllerProvider);
    final controller = ref.read(spendBlueCoinControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    ref.listen(spendBlueCoinControllerProvider.select((s) => s.result), (prev, next) {
      if (next != null && prev != next) Navigator.of(context).pop(next);
    });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Spend Blue Coin', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Pay part of a bill at another merchant using your own Blue Coin. This settles immediately and cannot be undone.', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            if (state.target == null) ...[
              AppTextField(
                label: 'Merchant',
                hintText: 'Type a merchant name…',
                controller: _query,
                prefixIcon: Icons.search_rounded,
                onChanged: (v) => setState(() => _search = v.trim()),
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MerchantResults(query: _search, onPick: controller.setTarget),
            ] else ...[
              AppCard(
                compact: true,
                child: Row(
                  children: [
                    MerchantLogo(url: state.target!.logoUrl, merchantName: state.target!.name, size: AppSize.avatarMd),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.target!.name, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${_trim(state.target!.discountRate ?? 0)}% Town Coin discount', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => controller.setTarget(null), child: const Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(
                label: 'Bill amount (₹)',
                controller: _amount,
                hintText: '500.00',
                prefixIcon: Icons.currency_rupee_rounded,
                helperText: "Capped by that merchant's discount rate and your Blue Coin balance (${widget.blueBalance}).",
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: controller.setBillAmount,
                autofocus: true,
              ),
              if (state.isAmountValid) ...[
                const SizedBox(height: AppSpacing.smd),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  child: Row(
                    children: [
                      Expanded(child: Text('Estimated discount', style: textTheme.bodyMedium)),
                      Text(formatMoney(state.estimatedDiscount(widget.blueBalance)), style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.goldDark)),
                    ],
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(label: state.isSubmitting ? 'Spending…' : 'Spend Blue Coin', icon: Icons.send_rounded, isLoading: state.isSubmitting, onPressed: state.canSubmit ? controller.submit : null),
            ],
          ],
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _MerchantResults extends ConsumerWidget {
  const _MerchantResults({required this.query, required this.onPick});

  final String query;
  final ValueChanged<Merchant> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(spendTargetMerchantsProvider(query));
    return results.when(
      loading: () => const LoadingSkeletonList(count: 3, padding: EdgeInsets.zero),
      error: (e, _) => ErrorState(compact: true, error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(spendTargetMerchantsProvider(query))),
      data: (list) {
        if (list.isEmpty) return Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(query.isEmpty ? 'No merchants accept Town Coin yet.' : 'No merchants match "$query".', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center));
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) {
              final m = list[i];
              return ListTile(
                leading: MerchantLogo(url: m.logoUrl, merchantName: m.name, size: AppSize.avatarMd),
                title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${m.category?.name ?? ''}${m.discountRate != null ? ' · ${m.discountRate}% coin discount' : ''}'),
                onTap: () => onPick(m),
              );
            },
          ),
        );
      },
    );
  }
}
