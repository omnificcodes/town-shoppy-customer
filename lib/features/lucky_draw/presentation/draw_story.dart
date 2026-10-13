import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/indian_mobile.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../application/draws_list_controller.dart';
import '../data/models/draw.dart';
import '../data/models/draw_entry.dart';
import '../data/models/draw_winner.dart';
import '../data/models/prize.dart';
import 'draw_status_display.dart';

/// The full story of a completed draw (BR-44), shared by the customer's
/// draw page and Business mode's: a hero with the headline numbers, the
/// "Watch the draw" replay, every winner, every prize with its units, the
/// sponsor shops, where the entries came from, every entry, and who
/// conducted the draw. It renders exactly what the API sent -- a shop sees
/// the full details of the winners of its own gifts because the backend
/// included them, a customer sees masked labels because it did not.
class DrawStoryBody extends ConsumerWidget {
  const DrawStoryBody({super.key, required this.draw, required this.watchPath, this.business = false});

  final Draw draw;

  /// Where "Watch the draw" goes (the show screen for this draw).
  final String watchPath;

  /// Business mode: maroon hero, no "My winnings" box.
  final bool business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final winners = ref.watch(drawWinnersProvider(draw.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
      children: [
        _Hero(draw: draw, business: business, winnerCount: winners.value?.length),
        const SizedBox(height: AppSpacing.md),
        if (draw.isComplete)
          AppButton(
            label: 'Watch the draw',
            icon: Icons.play_circle_fill_rounded,
            onPressed: () => context.push(watchPath),
          ),
        if (!business) ...[
          const SizedBox(height: AppSpacing.sm),
          InfoBox(
            tone: AppTone.neutral,
            icon: Icons.shuffle_rounded,
            message: 'Winners are drawn at random from every eligible coupon. '
                'Any prize you win appears under My winnings with its claim code.',
            action: AppButton(
              label: 'View my winnings',
              variant: AppButtonVariant.text,
              size: AppButtonSize.sm,
              expand: false,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.push('/lucky-draw/my-wins'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Winners', subtitle: 'One coupon per prize unit'),
        const SizedBox(height: AppSpacing.sm),
        winners.when(
          loading: () => const LoadingSkeletonCard(),
          error: (error, _) => ErrorState(
            compact: true,
            error: error is AppException ? error : const UnknownAppException(),
            title: 'Could not load winners',
            onRetry: () => ref.invalidate(drawWinnersProvider(draw.id)),
          ),
          data: (list) {
            final shown = list.where((w) => w.status != 'forfeited').toList();
            if (shown.isEmpty) {
              return const EmptyState(
                compact: true,
                icon: Icons.emoji_events_outlined,
                title: 'No winners published yet',
                message: 'Winners appear here once the draw has been run and verified.',
              );
            }
            return Column(
              children: [
                for (final winner in shown) ...[
                  _WinnerCard(winner: winner),
                  if (winner != shown.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Prizes', subtitle: 'What was on offer, and how many units went in'),
        const SizedBox(height: AppSpacing.sm),
        if (draw.prizes.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.card_giftcard_outlined,
            title: 'No prize details published',
            message: 'This draw has no prize list attached.',
          )
        else
          for (final prize in draw.prizes) ...[
            _PrizeCard(prize: prize),
            if (prize != draw.prizes.last) const SizedBox(height: AppSpacing.sm),
          ],
        if (draw.sponsorShops.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Sponsor shops', subtitle: 'The businesses behind the gifts'),
          const SizedBox(height: AppSpacing.sm),
          _SponsorShops(shops: draw.sponsorShops),
        ],
        if (draw.entriesByShop.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          SectionHeader(
            title: 'Where the entries came from',
            subtitle: draw.poolSize != null ? '${draw.poolSize} coupons in the locked pool' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _EntriesByShop(rows: draw.entriesByShop, total: draw.poolSize ?? draw.entriesByShop.fold(0, (s, r) => s + r.entries)),
        ],
        if (draw.scope == 'selected_merchants' && draw.merchantScopes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Businesses in this draw'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [for (final name in draw.merchantScopes) _Chip(label: name, icon: Icons.storefront_rounded)],
          ),
        ],
        if (draw.isComplete) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'All entries', subtitle: 'Every coupon in the draw, and where it was earned'),
          const SizedBox(height: AppSpacing.sm),
          _EntriesList(drawId: draw.id),
        ],
        if (draw.coordinatorName != null || draw.witnessNames.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Conducted by', subtitle: 'Recorded when the draw was run'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (draw.coordinatorName != null)
                  _PersonRow(icon: Icons.verified_user_rounded, role: 'Coordinator', name: draw.coordinatorName!),
                for (final witness in draw.witnessNames) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _PersonRow(icon: Icons.how_to_reg_rounded, role: 'Witness', name: witness),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.draw, required this.business, required this.winnerCount});

  final Draw draw;
  final bool business;
  final int? winnerCount;

  @override
  Widget build(BuildContext context) {
    final gradient = business
        ? const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep])
        : const LinearGradient(colors: [AppColors.orange, AppColors.orangeDeep]);
    final subtitle = <String>[
      if (draw.associationName != null) draw.associationName!,
      if (draw.executedAt != null) 'Drawn ${formatDate(draw.executedAt!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppElevation.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: AppIconSize.lg),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drawCadenceTitle(draw.cadence),
                      style: AppTypography.textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    // Under the title, not beside it: at large text sizes a
                    // badge beside a 40px avatar leaves a 320px phone no
                    // room for the title at all.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(
                        label: draw.isComplete ? 'Complete' : draw.status,
                        tone: draw.isComplete ? AppTone.success : AppTone.neutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HeroStat(label: 'Entries', value: '${draw.poolSize ?? '—'}'),
              _HeroStat(label: 'Winners', value: '${winnerCount ?? draw.winnerCount ?? '—'}'),
              _HeroStat(label: 'Prize units', value: '${draw.unitsAwarded}/${draw.unitsInDraw}'),
              _HeroStat(label: 'Shops', value: '${draw.sponsorShops.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.numericFinancialMedium.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label.toUpperCase(), style: AppTypography.badgeLabel.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.winner});

  final DrawWinner winner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final prize = winner.prize;
    final phone = dialableIndianMobile(winner.winnerMobileNumber);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                decoration: const BoxDecoration(color: AppColors.orangeTint, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: AppIconSize.md),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(winner.displayName, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (winner.winnerName != null)
                      Text(winner.winnerLabel, style: textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (prize != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Won ${prize.name}${prize.sponsorMerchantName != null ? ' from ${prize.sponsorMerchantName}' : ''}',
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (winner.claimStatus != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: voucherStatusLabel(winner.claimStatus!), tone: voucherStatusTone(winner.claimStatus!)),
              ],
            ],
          ),
          if (winner.earnedAtShopName != null || winner.couponCode != null || phone != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (winner.earnedAtShopName != null) _Chip(label: 'Coupon from ${winner.earnedAtShopName}', icon: Icons.storefront_rounded),
                if (winner.couponCode != null) _Chip(label: winner.couponCode!, icon: Icons.confirmation_number_rounded, mono: true),
                if (phone != null)
                  ActionChip(
                    avatar: const Icon(Icons.call_rounded, size: AppIconSize.sm, color: AppColors.orangeDeep),
                    label: Text(winner.winnerMobileNumber!),
                    onPressed: () => launchUrl(telUri(phone)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.prize});

  final Prize prize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final won = prize.unitsAwarded ?? 0;
    final inDraw = prize.unitsInDraw;

    return AppCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              color: AppColors.orangeTint,
              child: prize.imageUrl != null
                  ? Image.network(prize.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _PrizeIcon())
                  : const _PrizeIcon(),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prize.name, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (prize.sponsorMerchantName != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Sponsored by ${prize.sponsorMerchantName}', style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    if (prize.value != null) _Chip(label: formatMoney(prize.value!), icon: Icons.sell_rounded),
                    _Chip(label: '$won of $inDraw unit${inDraw == 1 ? '' : 's'} won here', icon: Icons.emoji_events_outlined),
                    if (prize.quantityRemaining > 0) _Chip(label: '${prize.quantityRemaining} left for a later draw', icon: Icons.update_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeIcon extends StatelessWidget {
  const _PrizeIcon();

  @override
  Widget build(BuildContext context) => const Icon(Icons.card_giftcard_rounded, color: AppColors.orange, size: AppIconSize.lg);
}

class _SponsorShops extends StatelessWidget {
  const _SponsorShops({required this.shops});

  final List<DrawSponsorShop> shops;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final shop in shops) ...[
          AppCard(
            child: Row(
              children: [
                MerchantLogo(url: shop.logoUrl, merchantName: shop.name, size: AppSize.avatarMd),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(shop.prizeNames.join(', '), style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${shop.unitsAwarded}', style: textTheme.titleMedium),
                    Text(shop.unitsAwarded == 1 ? 'gift won' : 'gifts won', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          if (shop != shops.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _EntriesByShop extends StatelessWidget {
  const _EntriesByShop({required this.rows, required this.total});

  final List<DrawShopEntries> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(child: Text(row.name, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: AppSpacing.sm),
                Text('${row.entries}', style: AppTypography.numericFinancialSmall.copyWith(color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : row.entries / total,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.orange,
              ),
            ),
            if (row != rows.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// The full entry list, a page at a time, each page its own provider so a
/// retry re-reads only the page that failed.
class _EntriesList extends ConsumerStatefulWidget {
  const _EntriesList({required this.drawId});

  final int drawId;

  @override
  ConsumerState<_EntriesList> createState() => _EntriesListState();
}

class _EntriesListState extends ConsumerState<_EntriesList> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(drawEntriesPageProvider((widget.drawId, 1)));

    return first.when(
      loading: () => const LoadingSkeletonCard(),
      error: (error, _) => ErrorState(
        compact: true,
        error: error is AppException ? error : const UnknownAppException(),
        title: 'Could not load the entries',
        onRetry: () => ref.invalidate(drawEntriesPageProvider((widget.drawId, 1))),
      ),
      data: (firstPage) {
        if (firstPage.page.items.isEmpty) {
          return const EmptyState(
            compact: true,
            icon: Icons.confirmation_number_outlined,
            title: 'No entries',
            message: 'No coupons were in this pool.',
          );
        }
        final entries = <DrawEntry>[...firstPage.page.items];
        var loadingMore = false;
        for (var page = 2; page <= _pages; page++) {
          final next = ref.watch(drawEntriesPageProvider((widget.drawId, page)));
          if (next.isLoading) loadingMore = true;
          entries.addAll(next.value?.page.items ?? const []);
        }
        final hasMore = _pages < firstPage.page.lastPage;

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _EntryRow(entry: entries[i]),
                if (i != entries.length - 1) const Divider(height: 1, color: AppColors.border),
              ],
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: AppButton(
                    label: 'Show more (${firstPage.page.total - entries.length} left)',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.sm,
                    isLoading: loadingMore,
                    onPressed: loadingMore ? null : () => setState(() => _pages++),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final DrawEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            entry.isWinner ? Icons.emoji_events_rounded : Icons.confirmation_number_outlined,
            size: AppIconSize.sm,
            color: entry.isWinner ? AppColors.orange : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (entry.shopName != null) entry.shopName!,
                    if (entry.entrantMobileNumber != null) entry.entrantMobileNumber!,
                    if (entry.couponCode != null) entry.couponCode!,
                  ].join(' · '),
                  style: textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (entry.isWinner) ...[
            const SizedBox(width: AppSpacing.sm),
            const StatusBadge(label: 'Winner', tone: AppTone.success),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.icon, required this.role, required this.name});

  final IconData icon;
  final String role;
  final String name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(name, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(role, style: textTheme.labelSmall),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, this.mono = false});

  final String label;
  final IconData icon;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(fontFamily: mono ? 'monospace' : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
