import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/scratch_cards_providers.dart';
import '../data/models/scratch_card.dart';
import '../data/scratch_cards_repository.dart';
import 'confetti_burst.dart';
import 'scratch_card_theme.dart';
import 'scratch_foil.dart';

/// The reveal. A themed backdrop, the card under silver foil the customer
/// rubs away; the first stroke asks the server to scratch (so the prize is
/// known), and once about half the foil is gone the rest melts away with a
/// chime, confetti and a bounce. An already-scratched card opens revealed,
/// quietly, with its code and status.
class ScratchCardScreen extends ConsumerStatefulWidget {
  const ScratchCardScreen({super.key, required this.cardId});

  final int cardId;

  @override
  ConsumerState<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends ConsumerState<ScratchCardScreen> with TickerProviderStateMixin {
  static const _revealAt = 0.5;

  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _player = AudioPlayer();

  /// The card as the server returned it from `scratch` -- the prize.
  CustomerScratchCard? _revealed;
  bool _scratching = false;
  bool _celebrated = false;
  AppException? _error;

  @override
  void dispose() {
    _reveal.dispose();
    _confetti.dispose();
    _bounce.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _onFirstTouch() async {
    if (_scratching || _revealed != null) return;
    setState(() => _scratching = true);
    try {
      final card = await ref.read(scratchCardsRepositoryProvider).scratch(widget.cardId);
      if (!mounted) return;
      setState(() => _revealed = card);
      // The list and the wallet now say something different.
      ref.invalidate(myScratchCardsProvider);
      if (card.reward?.isCoins == true) ref.read(walletControllerProvider.notifier).refresh();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _scratching = false);
    }
  }

  void _onProgress(double fraction) {
    if (_celebrated || fraction < _revealAt) return;
    if (_revealed == null) return; // the server has not answered yet; keep rubbing
    _celebrate();
  }

  Future<void> _celebrate() async {
    if (_celebrated) return;
    _celebrated = true;
    HapticFeedback.heavyImpact();
    _reveal.forward();
    _bounce.forward(from: 0);
    _confetti.forward(from: 0);
    try {
      await _player.play(AssetSource('sounds/scratch_win.wav'));
    } catch (_) {
      // No sound on this device/browser: the reveal is still complete.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scratchCardProvider(widget.cardId));
    final card = _revealed ?? async.value;
    final theme = ScratchCardTheme.of(card?.theme ?? 'gold');

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: theme.backdropGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(onBack: () => context.canPop() ? context.pop() : context.go('/scratch-cards')),
                  Expanded(
                    child: card == null
                        ? (async.hasError
                              ? ErrorState(
                                  error: async.error is AppException ? async.error! as AppException : const UnknownAppException(),
                                  onRetry: () => ref.invalidate(scratchCardProvider(widget.cardId)),
                                )
                              : const Center(child: CircularProgressIndicator(color: Colors.white)))
                        : _Body(
                            card: card,
                            theme: theme,
                            reveal: _reveal,
                            bounce: _bounce,
                            alreadyOpen: !card.isUnscratched && _revealed == null,
                            onFirstTouch: _onFirstTouch,
                            onProgress: _onProgress,
                            error: _error,
                          ),
                  ),
                ],
              ),
              Positioned.fill(child: ConfettiBurst(progress: _confetti)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.page, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Scratch card',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.card,
    required this.theme,
    required this.reveal,
    required this.bounce,
    required this.alreadyOpen,
    required this.onFirstTouch,
    required this.onProgress,
    required this.error,
  });

  final CustomerScratchCard card;
  final ScratchCardTheme theme;
  final Animation<double> reveal;
  final Animation<double> bounce;

  /// Opened after it was scratched earlier: no foil, no fanfare.
  final bool alreadyOpen;
  final VoidCallback onFirstTouch;
  final ValueChanged<double> onProgress;
  final AppException? error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showFoil = !alreadyOpen && !card.isExpired;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            alreadyOpen ? card.title : '${theme.emoji}  ${card.title}',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            alreadyOpen
                ? 'From ${card.shopName}'
                : card.isExpired
                ? 'This card from ${card.shopName} has expired.'
                : 'A gift from ${card.shopName}. Rub the silver to see what you won!',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AspectRatio(
                aspectRatio: 1.55,
                child: AnimatedBuilder(
                  animation: reveal,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.25 + 0.35 * reveal.value),
                          blurRadius: 28 + 30 * reveal.value,
                          spreadRadius: 2 + 6 * reveal.value,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _CardFace(card: card, theme: theme, bounce: bounce, alreadyOpen: alreadyOpen),
                          if (showFoil)
                            ScratchFoil(
                              enabled: reveal.value == 0,
                              onFirstTouch: onFirstTouch,
                              onProgress: onProgress,
                              revealProgress: Curves.easeOut.transform(reveal.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.smd),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(error!.message, style: textTheme.bodyMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _AfterReveal(card: card, reveal: reveal, alreadyOpen: alreadyOpen),
        ],
      ),
    );
  }
}

/// The card itself: themed gradient and, once revealed, the prize.
class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.theme, required this.bounce, required this.alreadyOpen});

  final CustomerScratchCard card;
  final ScratchCardTheme theme;
  final Animation<double> bounce;
  final bool alreadyOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reward = card.reward;
    final ink = Colors.black.withValues(alpha: 0.78);

    Widget prize;
    if (card.isExpired && reward == null) {
      prize = Text('Expired', style: textTheme.headlineMedium?.copyWith(color: ink, fontWeight: FontWeight.w900));
    } else if (reward == null) {
      // Still hidden: this is only ever seen through the foil's clear strokes.
      prize = Icon(Icons.card_giftcard_rounded, size: 72, color: ink.withValues(alpha: 0.35));
    } else if (reward.isCoins) {
      prize = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('YOU WON', style: textTheme.labelLarge?.copyWith(color: ink, letterSpacing: 3, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '+${reward.coinAmount}',
            style: textTheme.displayMedium?.copyWith(color: ink, fontWeight: FontWeight.w900, height: 1),
          ),
          Text('Town Coins', style: textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w800)),
        ],
      );
    } else {
      prize = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('YOU WON', style: textTheme.labelLarge?.copyWith(color: ink, letterSpacing: 3, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reward.offerText ?? '',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w900, height: 1.15),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CodeChip(code: reward.formattedCode, dark: true),
        ],
      );
    }

    final scale = alreadyOpen
        ? const AlwaysStoppedAnimation(1.0)
        : Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: bounce, curve: Curves.elasticOut));

    return DecoratedBox(
      decoration: BoxDecoration(gradient: theme.faceGradient),
      child: Stack(
        children: [
          // Soft light across the top, like glossy card stock.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.08)],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.smd,
            left: AppSpacing.md,
            child: Text(
              card.shopName.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(color: ink.withValues(alpha: 0.7), letterSpacing: 2, fontWeight: FontWeight.w800),
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.md,
            child: Text(theme.emoji, style: const TextStyle(fontSize: 22)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
              child: ScaleTransition(scale: scale, child: prize),
            ),
          ),
        ],
      ),
    );
  }
}

/// What to do next, shown once the foil is gone (or at once for a card
/// opened later): the code to show, the coins now in the wallet, dates
/// and the card's status.
class _AfterReveal extends StatelessWidget {
  const _AfterReveal({required this.card, required this.reveal, required this.alreadyOpen});

  final CustomerScratchCard card;
  final Animation<double> reveal;
  final bool alreadyOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reward = card.reward;
    final muted = Colors.white.withValues(alpha: 0.8);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reward?.isOffer == true) ...[
          if (card.isRedeemed)
            _Note(icon: Icons.check_circle_rounded, text: 'Used at ${card.shopName}${card.redeemedAt != null ? ' on ${formatDateTime(card.redeemedAt!)}' : ''}.')
          else if (card.isExpired)
            _Note(icon: Icons.schedule_rounded, text: 'This offer expired${card.expiresAt != null ? ' on ${formatDate(card.expiresAt!)}' : ''}.')
          else ...[
            Text(
              'Show this code at ${card.shopName} to claim your offer.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: _CodeChip(code: reward!.formattedCode, dark: false, copyable: true)),
            if (card.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Valid till ${formatDate(card.expiresAt!)}', textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ],
        ] else if (reward?.isCoins == true) ...[
          _Note(icon: Icons.account_balance_wallet_rounded, text: '${reward!.coinAmount} Town Coins were added to your wallet.'),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'View wallet',
            icon: Icons.account_balance_wallet_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push('/wallet'),
          ),
        ] else if (card.isExpired) ...[
          _Note(icon: Icons.schedule_rounded, text: 'This card expired before it was scratched.'),
        ],
        if (card.createdAt != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Given with your purchase on ${formatDate(card.createdAt!)}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );

    if (alreadyOpen || card.isExpired) return content;

    // Rises into place as the foil melts away.
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) => Opacity(
        opacity: reveal.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - reveal.value)), child: child),
      ),
      child: content,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// The 8-character code, big and spaced for reading out at the counter.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, required this.dark, this.copyable = false});

  final String code;
  final bool dark;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.black.withValues(alpha: 0.8) : AppColors.textPrimary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.55) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.6) : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (copyable) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.copy_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
          ],
        ],
      ),
    );

    if (!copyable) return chip;

    return Semantics(
      button: true,
      label: 'Copy code $code',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code.replaceAll('-', '')));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied.')));
        },
        child: chip,
      ),
    );
  }
}
