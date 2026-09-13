import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/business_branches_controller.dart';
import '../../application/direct_pos_controller.dart';
import '../business_qr_scan_screen.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// The counter. Step 1 identifies the customer (scan their QR, or type
/// their number and look them up -- registering them inline if they are
/// new); step 2 takes the bill, the branch when there is more than one,
/// and whether to spend their Town Coins on it, with a live preview of
/// the discount. Record -> celebration -> the new purchase.
class DirectPosScreen extends ConsumerStatefulWidget {
  const DirectPosScreen({super.key});

  @override
  ConsumerState<DirectPosScreen> createState() => _DirectPosScreenState();
}

class _DirectPosScreenState extends ConsumerState<DirectPosScreen> {
  final _mobile = TextEditingController();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _mobile.dispose();
    _name.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await context.push<String>(BusinessRoutes.scan, extra: BusinessScanArgs.customerQr);
    if (value != null && mounted) ref.read(directPosControllerProvider.notifier).setQrToken(value);
  }

  void _reset() {
    _mobile.clear();
    _name.clear();
    _amount.clear();
    _reference.clear();
    ref.read(directPosControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directPosControllerProvider);
    final controller = ref.read(directPosControllerProvider.notifier);
    final branches = ref.watch(activeBranchesProvider);
    final textTheme = Theme.of(context).textTheme;

    // The single-branch case is derived, never stored: the backend falls
    // back to the primary branch when none is sent.
    final effectiveBranchId = state.branchId ?? (branches.length == 1 ? branches.first.id : null);

    ref.listen(directPosControllerProvider.select((s) => s.result), (prev, next) async {
      if (next == null || prev == next) return;
      final purchaseId = next.purchase.id;
      await showPurchaseCelebration(
        context,
        title: 'Purchase recorded!',
        discountAmount: next.redeemedCoins > 0 ? next.discountAmount : null,
        coinsRedeemed: next.redeemedCoins > 0 ? next.redeemedCoins : null,
        coinsAwarded: next.purchase.coinsAwarded,
      );
      if (!context.mounted) return;
      if (next.duplicateWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.duplicateWarning!), duration: const Duration(seconds: 6)));
      }
      _reset();
      context.pushReplacement('${BusinessRoutes.purchases}/$purchaseId');
    });

    return BusinessScaffold(
      title: 'Direct POS',
      padded: false,
      actions: [IconButton(icon: const Icon(Icons.restart_alt_rounded), tooltip: 'Reset', onPressed: state.isSubmitting ? null : _reset)],
      bottomBar: AppButton(
        label: state.isSubmitting ? 'Recording…' : 'Record purchase',
        icon: Icons.check_circle_rounded,
        size: AppButtonSize.lg,
        isLoading: state.isSubmitting,
        onPressed: state.canSubmit ? controller.submit : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (state.subscriptionReason != null) ...[
            InfoBox(
              icon: Icons.lock_rounded,
              tone: AppTone.error,
              title: state.subscriptionReason == 'quota_exhausted' ? "This period's coupon quota is used up" : 'An active subscription is required',
              message: 'Recording purchases needs a subscribed plan. Visit Subscriptions to continue.',
              action: AppButton(label: 'Subscriptions', size: AppButtonSize.sm, expand: false, variant: AppButtonVariant.secondary, onPressed: () => context.push(BusinessRoutes.subscriptions)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _StepHeader(number: 1, title: 'Customer', subtitle: 'Identify who this purchase belongs to.'),
          const SizedBox(height: AppSpacing.smd),
          SegmentedButton<DirectPosMethod>(
            segments: const [
              ButtonSegment(value: DirectPosMethod.mobile, label: Text('Mobile number'), icon: Icon(Icons.smartphone_rounded)),
              ButtonSegment(value: DirectPosMethod.qr, label: Text('Scan customer QR'), icon: Icon(Icons.qr_code_scanner_rounded)),
            ],
            selected: {state.method},
            onSelectionChanged: state.isSubmitting
                ? null
                : (s) {
                    _mobile.clear();
                    _name.clear();
                    controller.setMethod(s.first);
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.method == DirectPosMethod.mobile) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Customer mobile number',
                    controller: _mobile,
                    hintText: '9876543210',
                    prefixIcon: Icons.smartphone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                    enabled: !state.isSubmitting,
                    onChanged: controller.setMobile,
                    onSubmitted: (_) => controller.lookup(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: AppSize.field,
                  child: AppButton(
                    label: 'Search',
                    icon: Icons.search_rounded,
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    isLoading: state.isLookingUp,
                    onPressed: state.canSearch && !state.isSubmitting ? controller.lookup : null,
                  ),
                ),
              ],
            ),
            if (state.lookedUp?.registered == true) ...[
              const SizedBox(height: AppSpacing.smd),
              _LookupCard(result: state.lookedUp!),
            ],
            if (state.mustRegister) ...[
              const SizedBox(height: AppSpacing.smd),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.pending.withValues(alpha: 0.5)),
                  color: AppColors.pendingBg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: AppColors.pending, size: AppIconSize.md),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('No account found for this number.', style: textTheme.titleSmall?.copyWith(color: AppColors.pending))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Enter their name to register them. A brand-new customer has no coins to redeem yet.', style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(label: "Customer's full name", controller: _name, prefixIcon: Icons.person_outline_rounded, enabled: !state.isSubmitting, onChanged: controller.setCustomerName),
                  ],
                ),
              ),
            ],
          ] else ...[
            if (state.qrToken == null)
              AppButton(label: 'Open scanner', icon: Icons.qr_code_scanner_rounded, size: AppButtonSize.lg, onPressed: state.isSubmitting ? null : _scan)
            else
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.lg),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('QR code captured.', style: textTheme.titleSmall)),
                    TextButton(onPressed: state.isSubmitting ? null : () => controller.setQrToken(null), child: const Text('Scan another')),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.section),
          _StepHeader(number: 2, title: 'Purchase details', subtitle: 'Where, how much, and whether to redeem.'),
          const SizedBox(height: AppSpacing.smd),
          if (branches.length > 1) ...[
            DropdownButtonFormField<int>(
              value: effectiveBranchId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Branch', prefixIcon: Icon(Icons.location_on_outlined)),
              items: [for (final b in branches) DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))],
              onChanged: state.isSubmitting ? null : controller.setBranch,
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          AppTextField(
            label: 'Bill amount (₹)',
            controller: _amount,
            hintText: '500.00',
            prefixIcon: Icons.currency_rupee_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: AppTypography.numericFinancialMedium,
            enabled: !state.isSubmitting,
            onChanged: controller.setBillAmount,
            suffixIcon: state.isAmountValid ? const Icon(Icons.check_circle_rounded, color: AppColors.success) : null,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Bill reference (optional)', controller: _reference, hintText: 'Invoice or receipt number', prefixIcon: Icons.tag_rounded, enabled: !state.isSubmitting, onChanged: controller.setBillReference),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text("Apply the customer's Town Coin discount"),
            subtitle: const Text('Spends their available coins against this bill'),
            value: state.redeem,
            activeColor: AppColors.businessInk,
            onChanged: state.isSubmitting ? null : controller.setRedeem,
          ),
          if (state.redeem) ...[
            const SizedBox(height: AppSpacing.sm),
            if (state.preview == null)
              InfoBox(
                icon: Icons.sell_outlined,
                tone: AppTone.pending,
                message: 'Available Town Coin balance and discount will be shown after entering the customer and amount.',
                action: state.mustRegister
                    ? null
                    : AppButton(
                        label: state.isPreviewing ? 'Checking…' : 'Preview discount',
                        icon: Icons.visibility_outlined,
                        size: AppButtonSize.sm,
                        expand: false,
                        variant: AppButtonVariant.secondary,
                        isLoading: state.isPreviewing,
                        onPressed: state.hasIdentity && state.isAmountValid ? controller.previewDiscount : null,
                      ),
              )
            else
              _PreviewCard(state: state),
          ],
          if (state.error != null && state.subscriptionReason == null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title, required this.subtitle});

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppSize.avatarSm,
          height: AppSize.avatarSm,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.businessInk, shape: BoxShape.circle),
          child: Text('$number', style: AppTypography.badgeLabel.copyWith(color: AppColors.onBusinessInk)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: SectionHeader(title: title, subtitle: subtitle)),
      ],
    );
  }
}

class _LookupCard extends StatelessWidget {
  const _LookupCard({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.md),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.name as String? ?? 'Customer', style: textTheme.titleMedium),
                    Text(result.mobileNumber as String, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          if ((result.purchaseCount as int) > 0)
            Row(
              children: [
                _Stat(label: 'Purchases here', value: '${result.purchaseCount}'),
                _Stat(label: 'Total spent', value: formatMoney(result.totalSpent as double)),
                _Stat(label: 'Last visit', value: result.lastPurchaseAt != null ? formatDate(result.lastPurchaseAt as DateTime) : '—'),
              ],
            )
          else
            Text('First purchase at your business — they are registered with Town Shoppy but have not bought from you before.', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: AppTypography.numericFinancialSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.state});

  final DirectPosState state;

  @override
  Widget build(BuildContext context) {
    final p = state.preview!;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.customerName.toUpperCase(), style: AppTypography.overline.copyWith(color: AppColors.onBusinessInkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _PreviewStat(label: 'Available balance', value: '${p.availableBalance} coins'),
              _PreviewStat(label: 'Discount', value: formatMoney(p.maxDiscountAmount)),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('Customer pays', style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted))),
              Text(formatMoney(p.payableAmount), style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.yellow, fontSize: 32)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.onBusinessInkMuted)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.onBusinessInk)),
        ],
      ),
    );
  }
}
