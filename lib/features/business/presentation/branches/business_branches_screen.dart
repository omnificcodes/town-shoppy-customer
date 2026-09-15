import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/business_branches_controller.dart';
import '../../application/business_context.dart';
import '../../data/models/merchant_branch.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// Locations where customers can visit the business. Owners add/edit,
/// promote a primary and (de)activate; staff can only manage each
/// branch's Purchase QR -- exactly the web's split.
class BusinessBranchesScreen extends ConsumerStatefulWidget {
  const BusinessBranchesScreen({super.key});

  @override
  ConsumerState<BusinessBranchesScreen> createState() => _BusinessBranchesScreenState();
}

class _BusinessBranchesScreenState extends ConsumerState<BusinessBranchesScreen> {
  String _query = '';
  int? _busyId;

  Future<void> _run(int id, Future<void> Function() action, String successMessage) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _toggleStatus(MerchantBranch b) async {
    final deactivating = b.isActive;
    final ok = await showBusinessConfirmDialog(
      context,
      title: '${deactivating ? 'Deactivate' : 'Activate'} ${b.name}?',
      message: deactivating
          ? (b.isPrimary
              ? 'This is your primary branch — deactivating it will remove it from your public profile until you reactivate it or set a new primary branch.'
              : 'It will stop appearing to customers until you reactivate it. Offers and redemptions tied to it will pause too.')
          : 'It will become visible to customers again.',
      confirmLabel: deactivating ? 'Deactivate' : 'Activate',
      destructive: deactivating,
    );
    if (!ok) return;
    await _run(
      b.id,
      () => ref.read(businessBranchesControllerProvider.notifier).setStatus(b.id, active: !deactivating),
      '${b.name} ${deactivating ? 'deactivated' : 'reactivated'}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessBranchesControllerProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final merchant = ref.watch(myMerchantProvider).value;
    final all = async.value ?? const <MerchantBranch>[];
    final active = all.where((b) => b.isActive).length;
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? all
        : all.where((b) => [b.name, b.addressLine, b.locality, b.city, b.state, b.postalCode].whereType<String>().any((s) => s.toLowerCase().contains(q))).toList();

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Branches',
            subtitle: 'Locations where customers can visit your business',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            actions: [
              if (isOwner) BusinessHeaderIconButton(icon: Icons.add_rounded, tooltip: 'New branch', onTap: () => context.push(BusinessRoutes.branchNew)),
            ],
            child: BusinessStatStrip(
              isLoading: async.isLoading && async.value == null,
              stats: [
                BusinessStat(label: 'Total branches', value: '${all.length}'),
                BusinessStat(label: 'Active', value: '$active'),
                BusinessStat(label: 'Inactive', value: '${all.length - active}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search branches', hintText: 'Name, locality or city', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingSkeletonList(count: 3),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load your branches.', onRetry: () => ref.read(businessBranchesControllerProvider.notifier).refresh()),
              data: (_) {
                if (all.isEmpty) {
                  return EmptyState(
                    icon: Icons.location_on_outlined,
                    title: isOwner ? 'Add your first branch' : 'No branches on file',
                    message: isOwner ? 'Give customers a place to find you.' : "Your business doesn't have any branch locations yet.",
                    action: isOwner ? AppButton(label: 'New branch', icon: Icons.add_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.branchNew)) : null,
                  );
                }
                if (visible.isEmpty) {
                  return const EmptyState(icon: Icons.search_off_rounded, title: 'No branches match that search', message: 'Try a different name, locality, or city.');
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessBranchesControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                    itemBuilder: (context, i) => _BranchCard(
                      branch: visible[i],
                      fallbackImage: merchant?.coverImageUrl ?? merchant?.logoUrl,
                      isOwner: isOwner,
                      busy: _busyId == visible[i].id,
                      onQr: () => context.push('${BusinessRoutes.branches}/${visible[i].id}/qr', extra: visible[i]),
                      onEdit: () => context.push('${BusinessRoutes.branches}/${visible[i].id}/edit', extra: visible[i]),
                      onMakePrimary: () => _run(visible[i].id, () => ref.read(businessBranchesControllerProvider.notifier).setPrimary(visible[i].id), '${visible[i].name} is now your primary branch.'),
                      onToggleStatus: () => _toggleStatus(visible[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.fallbackImage,
    required this.isOwner,
    required this.busy,
    required this.onQr,
    required this.onEdit,
    required this.onMakePrimary,
    required this.onToggleStatus,
  });

  final MerchantBranch branch;
  final String? fallbackImage;
  final bool isOwner;
  final bool busy;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onMakePrimary;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final image = branch.coverImageUrl ?? fallbackImage;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  child: image == null
                      ? const ColoredBox(color: AppColors.businessTint, child: Icon(Icons.storefront_rounded, color: AppColors.businessInk))
                      : Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.businessTint, child: Icon(Icons.storefront_rounded, color: AppColors.businessInk))),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(branch.formattedAddress, style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (branch.isPrimary) const StatusBadge(label: 'Primary', tone: AppTone.info, icon: Icons.star_rounded),
                        StatusBadge(label: branch.isActive ? 'Active' : 'Inactive', tone: branch.isActive ? AppTone.success : AppTone.neutral),
                        if (branch.createdAt != null) StatusBadge(label: 'Added ${formatDate(branch.createdAt!)}', tone: AppTone.neutral),
                      ],
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  tooltip: 'Actions for ${branch.name}',
                  enabled: !busy,
                  onSelected: (v) => switch (v) {
                    'edit' => onEdit(),
                    'primary' => onMakePrimary(),
                    'status' => onToggleStatus(),
                    _ => null,
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit branch'))),
                    if (!branch.isPrimary && branch.isActive)
                      const PopupMenuItem(value: 'primary', child: ListTile(leading: Icon(Icons.star_outline_rounded), title: Text('Make primary'))),
                    PopupMenuItem(
                      value: 'status',
                      child: ListTile(
                        leading: Icon(branch.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: branch.isActive ? AppColors.error : null),
                        title: Text(branch.isActive ? 'Deactivate branch' : 'Activate branch', style: branch.isActive ? const TextStyle(color: AppColors.error) : null),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton(
            label: 'Purchase QR',
            icon: Icons.qr_code_2_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            isLoading: busy,
            onPressed: onQr,
          ),
        ],
      ),
    );
  }
}
