import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../stamp_cards/application/stamp_cards_providers.dart';
import '../../../stamp_cards/data/models/stamp_card.dart';
import '../../../stamp_cards/data/stamp_cards_repository.dart';
import '../../../stamp_cards/presentation/stamp_card_face.dart';
import '../../application/business_context.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// The counter finds a customer by mobile number, sees their card on each
/// running offer, and hands over the reward of a full one.
class StampCardCustomerScreen extends ConsumerStatefulWidget {
  const StampCardCustomerScreen({super.key});

  @override
  ConsumerState<StampCardCustomerScreen> createState() => _StampCardCustomerScreenState();
}

class _StampCardCustomerScreenState extends ConsumerState<StampCardCustomerScreen> {
  final _mobile = TextEditingController();
  List<CustomerStampCard>? _cards;
  String? _customerName;
  bool _busy = false;
  int? _rewardingId;
  String? _message;

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final merchantId = ref.read(myMerchantIdProvider);
    final mobile = _mobile.text.trim();
    if (merchantId == null || mobile.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _cards = null;
    });
    try {
      final result = await ref.read(stampCardsRepositoryProvider).lookup(merchantId: merchantId, mobileNumber: mobile);
      if (mounted) {
        setState(() {
          _cards = result.cards;
          _customerName = result.customerName;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reward(CustomerStampCard card) async {
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Reward given?',
      message: '${_customerName ?? 'The customer'} gets their ${card.rewardText}. The card is marked claimed and a fresh "${card.title}" card starts for them.',
      confirmLabel: 'Reward given',
    );
    if (!ok || !mounted) return;
    setState(() => _rewardingId = card.id);
    try {
      await ref.read(stampCardsRepositoryProvider).reward(card.id);
      ref.invalidate(stampCardProgrammesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked as claimed. Enjoy — ${card.rewardText}!')));
      }
      await _find();
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _rewardingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Find a customer\'s card',
      body: ListView(
        children: [
          AppTextField(
            label: 'Customer mobile number',
            controller: _mobile,
            hintText: '98765 43210',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            onChanged: (_) => setState(() => _message = null),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton(label: 'Find cards', icon: Icons.person_search_rounded, isLoading: _busy, onPressed: _busy ? null : _find),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: _message!),
          ],
          if (cards != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              (_customerName ?? 'Customer').toUpperCase(),
              style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (cards.isEmpty)
              const InfoBox(icon: Icons.loyalty_outlined, message: 'No stamp card is running right now.')
            else
              for (final card in cards) ...[
                StampCardFace(
                  title: card.title,
                  rewardText: card.rewardText,
                  stampsRequired: card.stampsRequired,
                  stampsCount: card.stampsCount,
                  icon: card.icon,
                  status: card.status,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (card.isFull)
                  AppButton(
                    label: 'Reward given — ${card.rewardText}',
                    icon: Icons.verified_rounded,
                    isLoading: _rewardingId == card.id,
                    onPressed: _rewardingId != null ? null : () => _reward(card),
                  )
                else
                  Text(
                    '${card.remaining} more ${card.remaining == 1 ? 'stamp' : 'stamps'} to go. Stamp it with their next bill at the counter.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        ],
      ),
    );
  }
}
