import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../stamp_cards/application/stamp_cards_providers.dart';
import '../../application/business_context.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import 'stamp_card_picker.dart';

/// The shop's stamp cards (BR-20c): how many the plan allows, a way to
/// find a customer's card and hand over a reward, and the cards
/// themselves. Owner designs; owner and staff stamp and reward.
class BusinessStampCardsScreen extends ConsumerWidget {
  const BusinessStampCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stampCardProgrammesProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Stamp cards',
      padded: false,
      bottomBar: isOwner && (async.value?.enabled ?? false)
          ? AppButton(
              label: 'New stamp card',
              icon: Icons.add_rounded,
              onPressed: (async.value?.canAddMore ?? false) ? () => context.push(BusinessRoutes.stampCardNew) : null,
            )
          : null,
      body: async.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load stamp cards.',
          onRetry: () => ref.invalidate(stampCardProgrammesProvider),
        ),
        data: (programmes) {
          if (!programmes.enabled) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                children: [
                  const InfoBox(
                    icon: Icons.workspace_premium_outlined,
                    message: 'Stamp cards are not included in your current plan. Bring customers back with "collect 5 stamps, get a free coffee" on a plan that includes them.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'See plans',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.workspace_premium_rounded,
                    onPressed: () => context.push(BusinessRoutes.subscriptions),
                  ),
                ],
              ),
            );
          }

          final limit = programmes.limit;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(stampCardProgrammesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.businessTint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.businessBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.loyalty_rounded, color: AppColors.businessInk, size: AppIconSize.lg),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              limit == null ? '${programmes.activeCount} running · no limit' : '${programmes.activeCount} of $limit running',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              programmes.canAddMore
                                  ? 'Stamp a customer\'s card with any bill at the counter or when approving a request.'
                                  : 'Switch a card off to run a different one.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Find a customer\'s card',
                  icon: Icons.person_search_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(BusinessRoutes.stampCardCustomer),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('YOUR CARDS', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.sm),
                if (programmes.items.isEmpty)
                  EmptyState(
                    icon: Icons.loyalty_outlined,
                    title: 'No stamp cards yet',
                    message: isOwner
                        ? 'Create your first card: how many stamps, and what the customer gets. Then stamp it with any bill.'
                        : 'The owner creates stamp cards here. Once there is one, you can stamp it with a bill at the counter.',
                  )
                else
                  for (final programme in programmes.items) ...[
                    StampProgrammeRow(
                      programme: programme,
                      onTap: isOwner ? () => context.push('${BusinessRoutes.stampCards}/${programme.id}/edit', extra: programme) : null,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(label: programme.isActive ? 'Running' : 'Off', tone: programme.isActive ? AppTone.success : AppTone.neutral),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${programme.collectingCount} collecting · ${programme.rewardedCount} claimed',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}
