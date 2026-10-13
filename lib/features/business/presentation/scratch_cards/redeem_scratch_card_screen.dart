import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../scratch_cards/application/scratch_cards_providers.dart';
import '../../../scratch_cards/data/models/scratch_card.dart';
import '../../../scratch_cards/data/scratch_cards_repository.dart';
import '../../../scratch_cards/presentation/scratch_card_theme.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// The counter types the code a customer reads out from a scratched offer
/// card, sees who it belongs to and what it gives, and marks it used.
class RedeemScratchCardScreen extends ConsumerStatefulWidget {
  const RedeemScratchCardScreen({super.key});

  @override
  ConsumerState<RedeemScratchCardScreen> createState() => _RedeemScratchCardScreenState();
}

class _RedeemScratchCardScreenState extends ConsumerState<RedeemScratchCardScreen> {
  final _code = TextEditingController();
  CustomerScratchCard? _card;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _card = null;
    });
    try {
      final card = await ref.read(scratchCardsRepositoryProvider).lookup(code);
      if (mounted) setState(() => _card = card);
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    final card = _card;
    if (card == null) return;
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Mark this code as used?',
      message: '${card.customerName ?? 'The customer'} gets "${card.reward?.offerText ?? ''}". The code cannot be used again.',
      confirmLabel: 'Mark as used',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(scratchCardsRepositoryProvider).redeem(card.id);
      ref.invalidate(scratchCardDesignsProvider);
      if (mounted) {
        setState(() => _card = updated);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code marked as used. Give the customer their offer.')));
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;

    return BusinessScaffold(
      title: 'Redeem a code',
      body: ListView(
        children: [
          const InfoBox(
            icon: Icons.info_outline_rounded,
            message: 'Ask the customer for the code on their scratched card. Letters and digits only; dashes and case do not matter.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Card code',
            controller: _code,
            hintText: 'ABCD-EFGH',
            textInputAction: TextInputAction.search,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')), _UpperCaseFormatter()],
            onChanged: (_) => setState(() => _message = null),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton(label: 'Find card', icon: Icons.search_rounded, isLoading: _busy && card == null, onPressed: _busy ? null : _find),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: _message!),
          ],
          if (card != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _FoundCard(card: card, busy: _busy, onRedeem: _redeem),
          ],
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.card, required this.busy, required this.onRedeem});

  final CustomerScratchCard card;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = ScratchCardTheme.of(card.theme);
    final reward = card.reward;
    final (label, tone) = switch (card.status) {
      'unscratched' => ('Not scratched yet', AppTone.pending),
      'scratched' => ('Ready to use', AppTone.success),
      'redeemed' => ('Already used', AppTone.neutral),
      _ => ('Expired', AppTone.error),
    };
    final canRedeem = card.status == 'scratched' && reward?.isOffer == true;
    final who = [card.customerName, card.customerMobileNumber].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: theme.faceGradient, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(theme.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(child: Text(card.title, style: textTheme.titleMedium)),
              StatusBadge(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          if (who.isNotEmpty) Text(who, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reward == null
                ? 'The prize shows once the customer has scratched the card.'
                : reward.isCoins
                ? '${reward.coinAmount} Town Coins — already in the customer\'s wallet; nothing to redeem here.'
                : reward.offerText ?? '',
            style: textTheme.titleSmall?.copyWith(color: AppColors.businessInk, fontWeight: FontWeight.w800),
          ),
          if (card.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Valid till ${formatDate(card.expiresAt!)}', style: AppTypography.caption),
          ],
          if (card.redeemedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Used on ${formatDateTime(card.redeemedAt!)}', style: AppTypography.caption),
          ],
          if (canRedeem) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Mark as used', icon: Icons.verified_rounded, isLoading: busy, onPressed: onRedeem),
          ],
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
