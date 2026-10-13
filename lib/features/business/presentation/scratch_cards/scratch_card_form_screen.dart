import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../scratch_cards/application/scratch_cards_providers.dart';
import '../../../scratch_cards/data/models/scratch_card.dart';
import '../../../scratch_cards/data/scratch_cards_repository.dart';
import '../../../scratch_cards/presentation/scratch_card_theme.dart';
import '../../application/business_context.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// Design a scratch card: what it is called, what it hides (a shop offer
/// or Town Coins), how long a given card stays valid, and its colour --
/// with a live preview of the card the customer will see.
class ScratchCardFormScreen extends ConsumerStatefulWidget {
  const ScratchCardFormScreen({super.key, this.design});

  /// Present when editing.
  final ScratchCardDesign? design;

  @override
  ConsumerState<ScratchCardFormScreen> createState() => _ScratchCardFormScreenState();
}

class _ScratchCardFormScreenState extends ConsumerState<ScratchCardFormScreen> {
  late final _title = TextEditingController(text: widget.design?.title ?? '');
  late final _offer = TextEditingController(text: widget.design?.offerText ?? '');
  late final _coins = TextEditingController(text: widget.design?.coinAmount?.toString() ?? '');
  late final _validity = TextEditingController(text: '${widget.design?.validityDays ?? 30}');
  late String _rewardType = widget.design?.rewardType ?? 'offer';
  late String _theme = widget.design?.theme ?? 'gold';
  late bool _active = widget.design?.isActive ?? true;

  bool _touched = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  bool get _isEdit => widget.design != null;

  @override
  void dispose() {
    for (final c in [_title, _offer, _coins, _validity]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _titleError => _title.text.trim().isEmpty ? 'Give the card a title.' : null;

  String? get _offerError => _rewardType == 'offer' && _offer.text.trim().isEmpty ? 'Write the offer the customer wins.' : null;

  String? get _coinsError {
    if (_rewardType != 'coins') return null;
    final n = int.tryParse(_coins.text.trim());
    return n == null || n < 1 ? 'Enter how many Town Coins the card gives.' : null;
  }

  String? get _validityError {
    final n = int.tryParse(_validity.text.trim());
    return n == null || n < 1 || n > 365 ? 'Enter 1 to 365 days.' : null;
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_titleError != null || _offerError != null || _coinsError != null || _validityError != null) return;

    final input = ScratchCardDesignInput(
      title: _title.text,
      rewardType: _rewardType,
      offerText: _offer.text,
      coinAmount: int.tryParse(_coins.text.trim()),
      validityDays: int.parse(_validity.text.trim()),
      theme: _theme,
      status: _active ? 'active' : 'inactive',
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final repo = ref.read(scratchCardsRepositoryProvider);
      final merchantId = ref.read(myMerchantIdProvider);
      if (!_isEdit && merchantId == null) return;
      if (_isEdit) {
        await repo.updateDesign(widget.design!.id, input);
      } else {
        await repo.createDesign(merchantId!, input);
      }
      ref.invalidate(scratchCardDesignsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text(_isEdit ? 'Design updated.' : 'Scratch card design added.')));
      context.go(BusinessRoutes.scratchCards);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
          _fieldErrors = e is ValidationAppException ? e.fieldErrors : const {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? server(String f) => _fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touched ? local : null;
    final theme = ScratchCardTheme.of(_theme);

    return BusinessScaffold(
      title: _isEdit ? 'Edit design' : 'New scratch card',
      padded: false,
      bottomBar: AppButton(label: _isEdit ? 'Save changes' : 'Add design', isLoading: _saving, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _Preview(title: _title.text, rewardType: _rewardType, offer: _offer.text, coins: _coins.text, theme: theme),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'The card', icon: Icons.card_giftcard_outlined),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Title',
            controller: _title,
            hintText: 'e.g. Festive surprise',
            maxLength: 80,
            errorText: server('title') ?? show(_titleError),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(
            title: 'What it hides',
            subtitle: 'Every card wins. Choose what the customer gets.',
            icon: Icons.redeem_outlined,
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Expanded(
                child: _TypeChoice(
                  label: 'Shop offer',
                  subtitle: 'With a code to show you',
                  icon: Icons.local_offer_rounded,
                  selected: _rewardType == 'offer',
                  onTap: () => setState(() => _rewardType = 'offer'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TypeChoice(
                  label: 'Town Coins',
                  subtitle: 'Added to their wallet',
                  icon: Icons.toll_rounded,
                  selected: _rewardType == 'coins',
                  onTap: () => setState(() => _rewardType = 'coins'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          if (_rewardType == 'offer')
            AppTextField(
              label: 'The offer',
              controller: _offer,
              hintText: 'e.g. 20% off your next visit',
              helperText: 'Shown with a unique code. The customer shows the code at your counter.',
              maxLines: 3,
              maxLength: 500,
              errorText: server('offer_text') ?? show(_offerError),
              onChanged: (_) => setState(() {}),
            )
          else
            AppTextField(
              label: 'Town Coins',
              controller: _coins,
              hintText: 'e.g. 50',
              helperText: 'Credited the moment the card is scratched. 1 coin = ₹1.',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: server('coin_amount') ?? show(_coinsError),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Valid for (days)',
            controller: _validity,
            hintText: '30',
            helperText: 'Counted from the day the card is given.',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: server('validity_days') ?? show(_validityError),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Colour', icon: Icons.palette_outlined),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              for (final t in ScratchCardTheme.all) ...[
                Expanded(child: _Swatch(theme: t, selected: t.key == _theme, onTap: () => setState(() => _theme = t.key))),
                if (t != ScratchCardTheme.all.last) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Availability', icon: Icons.visibility_outlined),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can be given at the counter'),
              subtitle: const Text('Turn off to stop giving this design. Cards already given are not affected.'),
              value: _active,
              activeColor: AppColors.businessInk,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(
              icon: Icons.error_outline_rounded,
              tone: AppTone.error,
              message: _fieldErrors.isEmpty ? _error!.message : 'Please fix the highlighted fields.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// The card as the customer will see it once scratched.
class _Preview extends StatelessWidget {
  const _Preview({required this.title, required this.rewardType, required this.offer, required this.coins, required this.theme});

  final String title;
  final String rewardType;
  final String offer;
  final String coins;
  final ScratchCardTheme theme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ink = Colors.black.withValues(alpha: 0.78);
    final prize = rewardType == 'coins'
        ? (coins.trim().isEmpty ? '+ ? Town Coins' : '+${coins.trim()} Town Coins')
        : (offer.trim().isEmpty ? 'Your offer appears here' : offer.trim());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: 1.7,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: theme.faceGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (title.trim().isEmpty ? 'Card title' : title.trim()).toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(color: ink.withValues(alpha: 0.7), letterSpacing: 2, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(theme.emoji, style: const TextStyle(fontSize: 20)),
                  ],
                ),
                const Spacer(),
                Text('YOU WON', style: textTheme.labelMedium?.copyWith(color: ink, letterSpacing: 3, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  prize,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const Spacer(),
                Text('PREVIEW', style: AppTypography.overline.copyWith(color: ink.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({required this.label, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.businessTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.smd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: selected ? AppColors.businessInk : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: selected ? AppColors.businessInk : AppColors.textSecondary),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text(subtitle, style: AppTypography.caption, maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.theme, required this.selected, required this.onTap});

  final ScratchCardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} colour',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: theme.faceGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: selected ? AppColors.textPrimary : Colors.transparent, width: 2.5),
              ),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.black87) : null,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(theme.label, style: AppTypography.caption.copyWith(fontWeight: selected ? FontWeight.w800 : null)),
          ],
        ),
      ),
    );
  }
}
