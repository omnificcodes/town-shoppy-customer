import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/business_branches_controller.dart';
import '../../data/models/merchant_branch.dart';
import '../business_routes.dart';

/// The docked Counter button's choice: show the counter Purchase QR for a
/// customer to scan (My QR), or record the bill yourself (My POS).
///
/// My QR goes straight to the branch's QR when there is one active branch,
/// asks which branch when there are several, and sends the merchant to
/// Branches when there are none yet (a Purchase QR belongs to a branch).
Future<void> showCounterActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl))),
    builder: (_) => const _CounterActionSheet(),
  );
}

class _CounterActionSheet extends ConsumerStatefulWidget {
  const _CounterActionSheet();

  @override
  ConsumerState<_CounterActionSheet> createState() => _CounterActionSheetState();
}

class _CounterActionSheetState extends ConsumerState<_CounterActionSheet> {
  bool _loadingBranches = false;

  /// Set once My QR finds more than one active branch.
  List<MerchantBranch>? _branchChoices;

  void _close(void Function(GoRouter router) then) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    then(router);
  }

  void _openPos() => _close((router) => router.push(BusinessRoutes.counter));

  void _openQr(MerchantBranch branch) =>
      _close((router) => router.push('${BusinessRoutes.branches}/${branch.id}/qr', extra: branch));

  Future<void> _chooseQr() async {
    setState(() => _loadingBranches = true);
    try {
      final branches = await ref.read(businessBranchesControllerProvider.future);
      if (!mounted) return;
      final active = branches.where((b) => b.isActive).toList();

      switch (active.length) {
        case 0:
          final messenger = ScaffoldMessenger.of(context);
          _close((router) => router.push(BusinessRoutes.branches));
          messenger.showSnackBar(
            const SnackBar(content: Text('Add an active branch to get your counter Purchase QR.')),
          );
        case 1:
          _openQr(active.single);
        default:
          setState(() {
            _loadingBranches = false;
            _branchChoices = active;
          });
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loadingBranches = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final choices = _branchChoices;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (choices != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => setState(() => _branchChoices = null),
                  ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      choices == null ? 'Counter' : 'Which branch?',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              choices == null
                  ? 'Let the customer scan your QR, or record the bill yourself.'
                  : 'Each branch has its own Purchase QR.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (choices == null) ...[
              _OptionTile(
                icon: Icons.qr_code_2_rounded,
                tint: AppColors.businessInk,
                title: 'My QR',
                subtitle: 'Show your counter Purchase QR for the customer to scan',
                loading: _loadingBranches,
                onTap: _loadingBranches ? null : _chooseQr,
              ),
              const SizedBox(height: AppSpacing.smd),
              _OptionTile(
                icon: Icons.point_of_sale_rounded,
                tint: AppColors.orangeDeep,
                title: 'My POS',
                subtitle: 'Record a bill yourself with Direct POS',
                onTap: _loadingBranches ? null : _openPos,
              ),
            ] else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final branch = choices[i];
                    final place = [branch.locality, branch.city].whereType<String>().where((s) => s.isNotEmpty);
                    return _OptionTile(
                      icon: Icons.storefront_rounded,
                      tint: AppColors.businessInk,
                      title: branch.name,
                      subtitle: [if (branch.isPrimary) 'Primary branch', ...place].join(' · '),
                      onTap: () => _openQr(branch),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: subtitle.isEmpty ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: AppSize.controlLg,
                    height: AppSize.controlLg,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(icon, color: tint, size: AppIconSize.lg),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(subtitle, style: AppTypography.caption),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (loading)
                    const SizedBox.square(dimension: AppIconSize.md, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
