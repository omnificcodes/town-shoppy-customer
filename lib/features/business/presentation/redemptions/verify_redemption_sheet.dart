import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../redemptions/data/models/redemption.dart';
import '../../application/business_redemptions_controller.dart';
import '../business_qr_scan_screen.dart';
import '../business_routes.dart';

/// Verifies one redemption. Three ways in, all ending at
/// `POST /redemptions/{id}/verify`:
///
/// * **Approve** (one tap, `counter_confirm`) -- only offered when the
///   customer raised it by scanning this branch's counter QR
///   (`counter_presence_verified`); the server re-checks the flag.
/// * **Scan** the customer's redemption QR (`qr`) -- camera, then the raw
///   value is sent as the code.
/// * **Type** the PIN (`otp`) or QR value by hand -- the web's only path.
///
/// Returns true when the redemption was verified.
Future<bool> showVerifyRedemptionSheet(BuildContext context, WidgetRef ref, {required Redemption redemption}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _VerifySheet(redemption: redemption),
    ),
  );
  return result ?? false;
}

class _VerifySheet extends ConsumerStatefulWidget {
  const _VerifySheet({required this.redemption});

  final Redemption redemption;

  @override
  ConsumerState<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends ConsumerState<_VerifySheet> {
  final _code = TextEditingController();
  String _method = 'otp';
  bool _busy = false;
  String? _localError;
  AppException? _serverError;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit({required String method, String? code}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _localError = null;
      _serverError = null;
    });
    try {
      await ref.read(businessRedemptionsControllerProvider.notifier).verify(widget.redemption.id, method: method, code: code);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _serverError = e;
        });
      }
    }
  }

  void _submitTyped() {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _localError = _method == 'qr' ? 'Enter the QR code value.' : 'Enter the OTP code.');
      return;
    }
    _submit(method: _method, code: code);
  }

  Future<void> _scan() async {
    final value = await context.push<String>(BusinessRoutes.scan, extra: BusinessScanArgs.redemptionQr);
    if (value == null || !mounted) return;
    setState(() {
      _method = 'qr';
      _code.text = value;
    });
    await _submit(method: 'qr', code: value);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = widget.redemption;
    final counter = r.isInitiated && r.counterPresenceVerified;
    final payable = r.maxDiscountAmount != null ? r.billAmount - r.maxDiscountAmount! : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verify redemption', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${r.customer?.name ?? 'Customer'} · bill ${formatMoney(r.billAmount)} · ${r.coinsRequested} coins',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (counter) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: AppColors.success, size: AppIconSize.md),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Started at your counter', style: textTheme.titleSmall?.copyWith(color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      payable != null
                          ? '${r.customer?.name ?? 'This customer'} is paying ${formatMoney(payable)} after a ${formatMoney(r.maxDiscountAmount!)} Town Coin discount.'
                          : 'This customer scanned your counter QR, so you can approve without a PIN.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.smd),
                    AppButton(label: 'Approve', icon: Icons.verified_rounded, isLoading: _busy, onPressed: () => _submit(method: 'counter_confirm')),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Or ask for their code', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
            ] else ...[
              const InfoBox(
                icon: Icons.key_rounded,
                message: 'Ask the customer for their code, then scan it or type it in below to confirm this redemption at the counter.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(label: 'Scan redemption QR', icon: Icons.qr_code_scanner_rounded, variant: AppButtonVariant.secondary, onPressed: _busy ? null : _scan),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'otp', label: Text('OTP / PIN'), icon: Icon(Icons.pin_rounded)),
                ButtonSegment(value: 'qr', label: Text('QR value'), icon: Icon(Icons.qr_code_2_rounded)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() {
                _method = s.first;
                _localError = null;
              }),
            ),
            const SizedBox(height: AppSpacing.smd),
            AppTextField(
              label: _method == 'qr' ? 'QR code value' : 'OTP code',
              controller: _code,
              keyboardType: _method == 'qr' ? TextInputType.text : TextInputType.number,
              inputFormatters: _method == 'qr' ? null : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              errorText: _localError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTyped(),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: _serverError!.message),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Verify', icon: Icons.verified_rounded, isLoading: _busy && !counter, onPressed: _busy ? null : _submitTyped),
          ],
        ),
      ),
    );
  }
}
