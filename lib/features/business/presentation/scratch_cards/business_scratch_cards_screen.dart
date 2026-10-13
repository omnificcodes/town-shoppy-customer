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
import '../../../scratch_cards/application/scratch_cards_providers.dart';
import '../../application/business_context.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import 'scratch_card_picker.dart';

/// The shop's scratch card designs (BR-20b): what is left this month, a
/// way to redeem a customer's code, and the designs themselves. Owner
/// designs; owner and staff redeem.
class BusinessScratchCardsScreen extends ConsumerWidget {
  const BusinessScratchCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scratchCardDesignsProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Scratch cards',
      padded: false,
      bottomBar: isOwner && (async.value?.enabled ?? false)
          ? AppButton(label: 'New design', icon: Icons.add_rounded, onPressed: () => context.push(BusinessRoutes.scratchCardNew))
          : null,
      body: async.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load scratch cards.',
          onRetry: () => ref.invalidate(scratchCardDesignsProvider),
        ),
        data: (designs) {
          if (!designs.enabled) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                children: [
                  const InfoBox(
                    icon: Icons.workspace_premium_outlined,
                    message: 'Scratch cards are not included in your current plan. Give customers a surprise with every bill — an offer with a code, or Town Coins — on a plan that includes them.',
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

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scratchCardDesignsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              children: [
                _MonthCard(remaining: designs.remaining),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Redeem a customer\'s code',
                  icon: Icons.qr_code_scanner_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(BusinessRoutes.scratchCardRedeem),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('YOUR DESIGNS', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: AppSpacing.sm),
                if (designs.items.isEmpty)
                  EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    title: 'No designs yet',
                    message: isOwner
                        ? 'Design your first scratch card: a title, what it hides, and a colour. Then give it with any bill at the counter.'
                        : 'The owner designs scratch cards here. Once there is one, you can give it with a bill at the counter.',
                  )
                else
                  for (final design in designs.items) ...[
                    ScratchCardDesignRow(
                      design: design,
                      onTap: isOwner ? () => context.push('${BusinessRoutes.scratchCards}/${design.id}/edit', extra: design) : null,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(label: design.isActive ? 'Active' : 'Off', tone: design.isActive ? AppTone.success : AppTone.neutral),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${design.givenCount} given · ${design.redeemedCount} used',
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

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.remaining});

  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final none = remaining == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: none ? AppColors.pendingBg : AppColors.businessTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: none ? AppColors.pending.withValues(alpha: 0.4) : AppColors.businessBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard_rounded, color: none ? AppColors.pending : AppColors.businessInk, size: AppIconSize.lg),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == null ? 'No monthly limit' : (none ? 'All cards used this month' : '$remaining cards left this month'),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  none
                      ? 'The count resets with your next billing month.'
                      : 'Give one with any bill at the counter or when approving a request.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
