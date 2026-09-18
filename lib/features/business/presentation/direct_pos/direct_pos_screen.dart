import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../application/business_branches_controller.dart';
import '../../application/business_context.dart';
import '../../application/direct_pos_controller.dart';
import '../../data/models/direct_pos.dart';
import '../business_qr_scan_screen.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';

/// The counter, following the Google Stitch redesign. Step 1 identifies
/// the customer (scan their QR, or type their number and look them up --
/// registering them inline if they are new); step 2 takes the bill, the
/// branch when there is more than one, and whether to spend their Town
/// Coins on it, with a live preview of the discount. Record -> celebration
/// -> the new purchase.
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
    final merchantName = ref.watch(myMerchantProvider).value?.name;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.duplicateWarning!), duration: const Duration(seconds: 6)));
      }
      _reset();
      context.pushReplacement('${BusinessRoutes.purchases}/$purchaseId');
    });

    final preview = state.redeem ? state.preview : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
          child: _RecordButton(
            label: state.isSubmitting ? 'Recording…' : 'Record purchase',
            isLoading: state.isSubmitting,
            onPressed: state.canSubmit ? controller.submit : null,
          ),
        ),
      ),
      body: Column(
        children: [
          _Header(merchantName: merchantName, onReset: state.isSubmitting ? null : _reset),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg),
              children: [
                if (state.subscriptionReason != null) ...[
                  InfoBox(
                    icon: Icons.lock_rounded,
                    tone: AppTone.error,
                    title: state.subscriptionReason == 'quota_exhausted'
                        ? "This period's coupon quota is used up"
                        : 'An active subscription is required',
                    message: 'Recording purchases needs a subscribed plan. Visit Subscriptions to continue.',
                    action: AppButton(
                      label: 'Subscriptions',
                      size: AppButtonSize.sm,
                      expand: false,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push(BusinessRoutes.subscriptions),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _StepCard(
                  number: 1,
                  title: 'Customer',
                  subtitle: 'Identify who this purchase belongs to.',
                  children: [
                    _MethodToggle(
                      selected: state.method,
                      onChanged: state.isSubmitting
                          ? null
                          : (method) {
                              _mobile.clear();
                              _name.clear();
                              controller.setMethod(method);
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.method == DirectPosMethod.mobile) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FieldBox(
                              controller: _mobile,
                              hintText: 'Customer mobile number',
                              semanticLabel: 'Customer mobile number',
                              prefix: const Icon(
                                Icons.smartphone_rounded,
                                size: AppIconSize.md,
                                color: AppColors.textSecondary,
                              ),
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
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(color: AppColors.pending.withValues(alpha: 0.4)),
                            color: AppColors.pendingBg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: AppColors.pending,
                                    size: AppIconSize.md,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'No account found for this number.',
                                      style: textTheme.titleSmall?.copyWith(color: AppColors.pending),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Enter their name to register them. A brand-new customer has no coins to redeem yet.',
                                style: textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _FieldBox(
                                controller: _name,
                                hintText: "Customer's full name",
                                semanticLabel: "Customer's full name",
                                prefix: const Icon(
                                  Icons.person_outline_rounded,
                                  size: AppIconSize.md,
                                  color: AppColors.textSecondary,
                                ),
                                enabled: !state.isSubmitting,
                                onChanged: controller.setCustomerName,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      if (state.qrToken == null)
                        AppButton(
                          label: 'Open scanner',
                          icon: Icons.qr_code_scanner_rounded,
                          size: AppButtonSize.lg,
                          onPressed: state.isSubmitting ? null : _scan,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xs,
                            AppSpacing.xs,
                            AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.lg),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text('QR code captured.', style: textTheme.titleSmall)),
                              TextButton(
                                onPressed: state.isSubmitting ? null : () => controller.setQrToken(null),
                                child: const Text('Scan another'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _StepCard(
                  number: 2,
                  title: 'Purchase details',
                  subtitle: 'Where, how much, and whether to redeem.',
                  children: [
                    if (branches.length > 1) ...[
                      const _FieldLabel('Branch'),
                      DropdownButtonFormField<int>(
                        value: effectiveBranchId,
                        isExpanded: true,
                        decoration: _boxDecoration(
                          hintText: 'Choose a branch',
                          prefix: const Icon(
                            Icons.location_on_outlined,
                            size: AppIconSize.md,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        items: [
                          for (final b in branches)
                            DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: state.isSubmitting ? null : controller.setBranch,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const _FieldLabel('Bill amount'),
                    _FieldBox(
                      controller: _amount,
                      hintText: '500.00',
                      semanticLabel: 'Bill amount (₹)',
                      prefix: Text(
                        '₹',
                        style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: AppTypography.numericFinancialMedium,
                      enabled: !state.isSubmitting,
                      onChanged: controller.setBillAmount,
                      suffix: state.isAmountValid
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FieldLabel('Bill reference (optional)'),
                    _FieldBox(
                      controller: _reference,
                      hintText: 'Invoice or receipt number',
                      semanticLabel: 'Bill reference (optional)',
                      prefix: Text('#', style: textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                      enabled: !state.isSubmitting,
                      onChanged: controller.setBillReference,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.md),
                    _CoinDiscountCard(
                      state: state,
                      onRedeemChanged: state.isSubmitting ? null : controller.setRedeem,
                      onPreview: state.hasIdentity && state.isAmountValid ? controller.previewDiscount : null,
                    ),
                  ],
                ),
                if (preview != null) ...[const SizedBox(height: AppSpacing.md), _PayableSummary(preview: preview)],
                if (state.error != null && state.subscriptionReason == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The shared look of every counter input: a warm filled box with a soft
/// border that turns orange on focus.
InputDecoration _boxDecoration({required String hintText, Widget? prefix, Widget? suffix}) {
  final radius = BorderRadius.circular(AppSpacing.radiusLg);
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: AppColors.surfaceMuted,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
            child: prefix,
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: AppSpacing.touchTarget, minHeight: 0),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.orangeDeep, width: 1.5),
    ),
  );
}

/// The deep maroon bar: back, the title with the business name, and reset.
class _Header extends StatelessWidget {
  const _Header({required this.merchantName, required this.onReset});

  final String? merchantName;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = merchantName;
    final canPop = Navigator.of(context).canPop();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.businessInkDeep, AppColors.businessInk],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
        boxShadow: AppElevation.floating,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
          child: Row(
            children: [
              if (canPop)
                _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: AppSpacing.touchTarget),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Direct POS',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.onBusinessInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (name != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: AppIconSize.xs, color: AppColors.yellow),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.overline.copyWith(
                                color: AppColors.yellow.withValues(alpha: 0.85),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RoundButton(icon: Icons.restart_alt_rounded, tooltip: 'Reset', onTap: onReset),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.onBusinessInk.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Icon(
              icon,
              size: AppIconSize.lg,
              color: AppColors.onBusinessInk.withValues(alpha: enabled ? 1 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white numbered card holding one step of the counter form.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title, required this.subtitle, required this.children});

  final int number;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: AppSize.avatarSm,
                  height: AppSize.avatarSm,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.businessInk, shape: BoxShape.circle),
                  child: Text(
                    '$number',
                    style: AppTypography.badgeLabel.copyWith(color: AppColors.yellow, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      label: 'Step $number, $title',
                      excludeSemantics: true,
                      child: Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Mobile number / Scan customer QR as one warm two-segment control.
class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.selected, required this.onChanged});

  final DirectPosMethod selected;
  final ValueChanged<DirectPosMethod>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MethodSegment(
                label: 'Mobile number',
                icon: Icons.smartphone_rounded,
                selected: selected == DirectPosMethod.mobile,
                onTap: onChanged == null ? null : () => onChanged!(DirectPosMethod.mobile),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _MethodSegment(
                label: 'Scan customer QR',
                icon: Icons.qr_code_scanner_rounded,
                selected: selected == DirectPosMethod.qr,
                onTap: onChanged == null ? null : () => onChanged!(DirectPosMethod.qr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodSegment extends StatelessWidget {
  const _MethodSegment({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.orangeTint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.orangeBorder : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.controlMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.check_rounded : icon,
                    size: AppIconSize.sm,
                    color: selected ? AppColors.orangeDeep : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.sm),
      child: ExcludeSemantics(
        child: Text(
          text.toUpperCase(),
          style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.controller,
    required this.hintText,
    required this.semanticLabel,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.style,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        style: style ?? Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        decoration: _boxDecoration(hintText: hintText, prefix: prefix, suffix: suffix),
      ),
    );
  }
}

/// A registered customer found by number: who they are and this
/// business's own history with them (the lookup never returns a balance).
class _LookupCard extends StatelessWidget {
  const _LookupCard({required this.result});

  final CustomerLookupResult result;

  static String _initials(String? name, String mobile) {
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    return mobile.length >= 2 ? mobile.substring(mobile.length - 2) : '?';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lastVisit = result.lastPurchaseAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: AppSize.avatarSm,
                  height: AppSize.avatarSm,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.businessInk.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(result.name, result.mobileNumber),
                    style: AppTypography.badgeLabel.copyWith(color: AppColors.businessInk, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name ?? 'Customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(result.mobileNumber, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.md),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          if (result.purchaseCount > 0)
            Row(
              children: [
                _Stat(label: 'Purchases here', value: '${result.purchaseCount}'),
                _Stat(label: 'Total spent', value: formatMoney(result.totalSpent)),
                _Stat(label: 'Last visit', value: lastVisit != null ? formatDate(lastVisit) : '—'),
              ],
            )
          else
            Text(
              'First purchase at your business — they are registered with Town Shoppy but have not bought from you before.',
              style: textTheme.bodySmall,
            ),
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
          Text(label, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: AppTypography.numericFinancialSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// The Town Coin switch and, when on, either the Preview discount prompt
/// or what the preview said: coins spent and the discount they buy.
class _CoinDiscountCard extends StatelessWidget {
  const _CoinDiscountCard({required this.state, required this.onRedeemChanged, required this.onPreview});

  final DirectPosState state;
  final ValueChanged<bool>? onRedeemChanged;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = state.preview;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxs),
                  child: Icon(Icons.auto_awesome_rounded, size: AppIconSize.md, color: AppColors.gold),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Apply the customer's Town Coin discount",
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Spends their available coins against this bill',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch.adaptive(
                  value: state.redeem,
                  activeTrackColor: AppColors.businessInk,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? AppColors.onBusinessInk : null,
                  ),
                  onChanged: onRedeemChanged,
                ),
              ],
            ),
          ),
          if (state.redeem) ...[
            const SizedBox(height: AppSpacing.smd),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.smd),
            if (preview == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sell_outlined, size: AppIconSize.sm, color: AppColors.pending),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Available Town Coin balance and discount will be shown after entering the customer and amount.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (!state.mustRegister) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: state.isPreviewing ? 'Checking…' : 'Preview discount',
                      icon: Icons.visibility_outlined,
                      size: AppButtonSize.sm,
                      expand: false,
                      variant: AppButtonVariant.secondary,
                      isLoading: state.isPreviewing,
                      onPressed: onPreview,
                    ),
                  ],
                ],
              )
            else ...[
              Text(
                preview.customerName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.toll_rounded, size: AppIconSize.sm, color: AppColors.gold),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Available balance: ${preview.availableBalance} coins',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: AppIconSize.sm, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Redeeming ${preview.maxRedeemableCoins} coins',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      child: Text(
                        '− ${formatMoney(preview.maxDiscountAmount)} off',
                        style: AppTypography.numericFinancialInline.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// What the customer pays after the previewed discount, with the bill
/// struck through beside it.
class _PayableSummary extends StatelessWidget {
  const _PayableSummary({required this.preview});

  final DirectPosPreview preview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Customer pays ${formatMoney(preview.payableAmount)}, bill ${formatMoney(preview.billAmount)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
        decoration: BoxDecoration(
          color: AppColors.businessInk.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.businessInk.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer pays', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  Text('After coin discount', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(preview.payableAmount),
                      style: AppTypography.numericFinancialMedium.copyWith(
                        color: AppColors.businessInkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (preview.billAmount != preview.payableAmount)
                    Text(
                      formatMoney(preview.billAmount),
                      style: AppTypography.caption.copyWith(decoration: TextDecoration.lineThrough),
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

/// The orange gradient Record purchase button; greyed while it cannot
/// submit.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.label, required this.isLoading, required this.onPressed});

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    final foreground = enabled || isLoading ? AppColors.onCrimson : AppColors.textSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: enabled ? AppElevation.floating : null),
        child: Material(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          color: AppColors.border,
          child: Ink(
            decoration: BoxDecoration(gradient: enabled || isLoading ? AppGradients.promoHero : null),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.controlLg + AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        SizedBox.square(
                          dimension: AppIconSize.md,
                          child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                        )
                      else
                        Icon(Icons.check_circle_rounded, color: foreground),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
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
