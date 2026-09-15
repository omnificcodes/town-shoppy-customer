import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_row.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/business_prizes_controller.dart';
import '../growth_status.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

class BusinessPrizeDetailScreen extends ConsumerStatefulWidget {
  const BusinessPrizeDetailScreen({super.key, required this.prizeId});

  final int prizeId;

  @override
  ConsumerState<BusinessPrizeDetailScreen> createState() => _BusinessPrizeDetailScreenState();
}

class _BusinessPrizeDetailScreenState extends ConsumerState<BusinessPrizeDetailScreen> {
  bool _busy = false;

  Future<void> _withdraw(String name) async {
    final ok = await showBusinessConfirmDialog(context, title: 'Withdraw $name?', message: 'This prize will no longer be available for any draw. This cannot be undone.', confirmLabel: 'Withdraw', destructive: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(businessPrizesControllerProvider.notifier).withdraw(widget.prizeId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prize withdrawn.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessPrizeProvider(widget.prizeId));
    final textTheme = Theme.of(context).textTheme;
    final prize = async.value;

    return BusinessScaffold(
      title: 'Prize',
      padded: false,
      bottomBar: prize != null && prize.canWithdraw ? AppButton(label: 'Withdraw prize', variant: AppButtonVariant.secondary, icon: Icons.block_rounded, isLoading: _busy, onPressed: () => _withdraw(prize.name)) : null,
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load this prize', onRetry: () => ref.invalidate(businessPrizeProvider(widget.prizeId))),
        data: (p) {
          final winners = p.winners ?? const [];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessPrizeProvider(widget.prizeId).future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _Placeholder())
                      : const _Placeholder(),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(label: prizeStatusLabel(p.status), tone: prizeStatusTone(p.status), large: true),
                      const SizedBox(height: AppSpacing.smd),
                      Text(p.name, style: textTheme.headlineMedium),
                      if (p.description != null && p.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(p.description!, style: textTheme.bodyMedium),
                      ],
                      if (winners.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        InfoBox(
                          icon: Icons.celebration_rounded,
                          tone: AppTone.success,
                          title: 'Congratulations!',
                          message: 'Your sponsored prize has ${winners.length == 1 ? 'a winner' : '${winners.length} winners'}.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.section),
                      const SectionHeader(title: 'Prize details', icon: Icons.emoji_events_rounded),
                      const SizedBox(height: AppSpacing.smd),
                      AppCard(
                        child: Column(
                          children: [
                            if (p.value != null) DetailRow(label: 'Approximate value', value: formatMoney(p.value!)),
                            DetailRow(label: 'Quantity total', value: '${p.quantityTotal}'),
                            DetailRow(label: 'Quantity remaining', value: '${p.quantityRemaining}'),
                            if (p.createdAt != null) DetailRow(label: 'Proposed', value: formatDateTime(p.createdAt!)),
                          ],
                        ),
                      ),
                      if (winners.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.section),
                        const SectionHeader(title: 'Winners', icon: Icons.military_tech_rounded),
                        const SizedBox(height: AppSpacing.smd),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (i, w) in winners.indexed) ...[
                                if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, color: AppColors.goldDark),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.winnerLabel ?? 'A customer', style: textTheme.titleSmall),
                                            if (w.claimedAt != null) Text('Claimed ${formatDateTime(w.claimedAt!)}', style: AppTypography.caption),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(label: voucherStatusLabel(w.claimStatus), tone: voucherStatusTone(w.claimStatus)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        switch (p.status) {
                          'draft' => 'Your association is reviewing this prize. It becomes available for a draw once approved.',
                          'available' => 'Approved — your association can allocate this prize to an upcoming draw.',
                          'allocated' => 'This prize is in a draw. It cannot be withdrawn now.',
                          'awarded' => 'This prize has been awarded. Thank you for sponsoring!',
                          'withdrawn' => 'This prize was withdrawn and will not be used in any draw.',
                          _ => '',
                        },
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.goldDark, AppColors.gold])),
      child: Center(child: Icon(Icons.emoji_events_rounded, color: AppColors.goldLight, size: AppIconSize.hero)),
    );
  }
}
