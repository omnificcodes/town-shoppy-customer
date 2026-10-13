import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../offers/data/models/offer.dart';
import '../../../offers/data/offers_repository.dart';

/// Flash sales running right now, soonest to end first (`GET
/// /offers?flash_sale=1`, BR-43). Per session, so a sign-in refreshes it.
final flashSalesProvider = FutureProvider<List<Offer>>((ref) async {
  ref.watch(sessionEpochProvider);
  final page = await ref.watch(offersRepositoryProvider).list(perPage: 10, flashSale: true);
  return page.items;
});

/// "Flash sales" on Home: a swipeable strip of offers with a live
/// countdown. Hidden while there are none, so Home never shows an empty
/// promise.
class FlashSalesStrip extends ConsumerWidget {
  const FlashSalesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final offers = (ref.watch(flashSalesProvider).value ?? const <Offer>[]).where((o) => o.endsAt == null || o.endsAt!.isAfter(now)).toList();
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.orange, size: AppIconSize.md),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Semantics(header: true, child: const Text('Flash sales', style: AppTypography.sectionTitle))),
              TextButton(onPressed: () => context.push('/offers'), child: const Text('See all')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => _FlashSaleCard(offer: offers[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashSaleCard extends StatelessWidget {
  const _FlashSaleCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${offer.title} at ${offer.merchantName}, flash sale',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/offers/${offer.id}'),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6A00), Color(0xFFFFB400)],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                    child: Text('⚡ FLASH SALE', style: textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ),
                  const Spacer(),
                  FlashCountdown(endsAt: offer.endsAt, style: textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xxs),
              Text(offer.merchantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ends in 2h 10m", ticking every second under an hour and every minute
/// above it. Shows "Ended" once past.
class FlashCountdown extends StatefulWidget {
  const FlashCountdown({super.key, required this.endsAt, this.style});

  final DateTime? endsAt;
  final TextStyle? style;

  /// Pure, so the label can be tested without a timer.
  static String label(DateTime? endsAt, DateTime now) {
    if (endsAt == null) return 'Limited time';
    final left = endsAt.difference(now);
    if (left.isNegative) return 'Ended';
    if (left.inDays >= 1) return 'Ends in ${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours >= 1) return 'Ends in ${left.inHours}h ${left.inMinutes % 60}m';
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return 'Ends in ${left.inMinutes}:$s';
  }

  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(FlashCountdown.label(widget.endsAt, DateTime.now()), style: widget.style);
  }
}
