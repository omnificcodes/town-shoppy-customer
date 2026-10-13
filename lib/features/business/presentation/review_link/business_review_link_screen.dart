import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../application/business_context.dart';
import '../../application/review_link_providers.dart';
import '../../data/models/review_link.dart';
import '../../data/review_link_repository.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import 'review_link_widgets.dart';

/// Magic review link (BR-20d): the shop's QR poster, how it is doing, and
/// the private notes from customers who were not happy. Before the owner
/// sets it up, a short explainer and the one field it needs.
class BusinessReviewLinkScreen extends ConsumerWidget {
  const BusinessReviewLinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewLinkProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);

    return BusinessScaffold(
      title: 'Review link',
      padded: false,
      body: async.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load your review link.',
          onRetry: () => ref.invalidate(reviewLinkProvider),
        ),
        data: (overview) {
          if (!overview.enabled) return const _NotInPlan();
          final link = overview.link;
          if (link == null) {
            return isOwner ? const _ReviewLinkSetup() : const _WaitingForOwner();
          }
          return _ReviewLinkDashboard(link: link, stats: overview.stats, isOwner: isOwner);
        },
      ),
    );
  }
}

class _NotInPlan extends StatelessWidget {
  const _NotInPlan();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const _SetupHero(),
        const SizedBox(height: AppSpacing.md),
        const InfoBox(
          icon: Icons.workspace_premium_outlined,
          message: 'Magic review link is not included in your current plan. Switch to a plan that includes it to start collecting Google reviews.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'See plans',
          variant: AppButtonVariant.secondary,
          icon: Icons.workspace_premium_rounded,
          onPressed: () => context.push(BusinessRoutes.subscriptions),
        ),
      ],
    );
  }
}

class _WaitingForOwner extends StatelessWidget {
  const _WaitingForOwner();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: const [
        _SetupHero(),
        SizedBox(height: AppSpacing.md),
        InfoBox(icon: Icons.info_outline_rounded, message: 'The shop owner sets up the review link. Once it is ready, the QR code shows here.'),
      ],
    );
  }
}

/// The maroon banner that explains the idea in one look.
class _SetupHero extends StatelessWidget {
  const _SetupHero();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.businessInk, AppColors.businessInkDeep],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ReviewStars(count: 5, size: 22),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Get more 5-star Google reviews',
                style: textTheme.titleLarge?.copyWith(color: AppColors.onBusinessInk, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Put one QR code at your counter. Happy customers go straight to your Google review page. Unhappy ones tell you privately, so you can put it right.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: const ReviewHowItWorks(),
        ),
      ],
    );
  }
}

/// First-time setup: paste the Google review link, get the QR.
class _ReviewLinkSetup extends ConsumerStatefulWidget {
  const _ReviewLinkSetup();

  @override
  ConsumerState<_ReviewLinkSetup> createState() => _ReviewLinkSetupState();
}

class _ReviewLinkSetupState extends ConsumerState<_ReviewLinkSetup> {
  final _url = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final value = _url.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Paste your Google review link.');
      return;
    }
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(reviewLinkRepositoryProvider).save(merchantId, googleReviewUrl: value);
      ref.invalidate(reviewLinkProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your review QR is ready! Put it at your counter.')));
      }
    } on ValidationAppException catch (e) {
      setState(() => _error = e.fieldErrors['google_review_url']?.first ?? e.message);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.lg),
            children: [
              const _SetupHero(),
              const SizedBox(height: AppSpacing.lg),
              Text('YOUR GOOGLE REVIEW LINK', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Google review link',
                controller: _url,
                hintText: 'https://g.page/r/…/review',
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: AppSpacing.smd),
              const _FindYourLinkHelp(),
            ],
          ),
        ),
        _StickyAction(
          child: AppButton(
            label: 'Create my review QR',
            icon: Icons.qr_code_2_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _create,
          ),
        ),
      ],
    );
  }
}

class _StickyAction extends StatelessWidget {
  const _StickyAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.all(AppSpacing.page), child: child),
      ),
    );
  }
}

/// Where the Google review link lives, step by step.
class _FindYourLinkHelp extends StatelessWidget {
  const _FindYourLinkHelp();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Open Google Maps or search your shop name on Google, signed in as the owner.',
      'On your Business Profile, tap "Ask for reviews" (or "Get more reviews").',
      'Tap "Copy link" and paste it above. It looks like https://g.page/r/…/review.',
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          leading: const Icon(Icons.help_outline_rounded, color: AppColors.info),
          title: Text('Where do I find this link?', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.info)),
          children: [
            for (final (i, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.info,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(step, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The link is set up: the poster, quick actions, results and notes.
class _ReviewLinkDashboard extends ConsumerWidget {
  const _ReviewLinkDashboard({required this.link, required this.stats, required this.isOwner});

  final ReviewLink link;
  final ReviewStats stats;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(myMerchantProvider).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reviewLinkProvider);
        ref.invalidate(reviewResponsesProvider(true));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
        children: [
          ReviewPoster(link: link, merchantName: merchant?.name ?? 'Your shop', logoUrl: merchant?.logoUrl),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy link',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link.publicUrl));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review link copied. Share it on WhatsApp or SMS.')));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Try it',
                  onTap: () => launchUrl(Uri.parse(link.publicUrl), mode: LaunchMode.externalApplication),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.edit_rounded,
                    label: 'Google link',
                    onTap: () => _showEditSheet(context, ref, link),
                  ),
                ),
              ],
            ],
          ),
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            _RunningSwitch(link: link),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('HOW IT IS GOING', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          _StatsGrid(stats: stats),
          const SizedBox(height: AppSpacing.md),
          _RatingBreakdown(stats: stats, threshold: link.googleThreshold),
          const SizedBox(height: AppSpacing.lg),
          const _FeedbackPreview(),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.businessInk),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner's on/off for the link. Off: a scan shows "not active".
class _RunningSwitch extends ConsumerStatefulWidget {
  const _RunningSwitch({required this.link});

  final ReviewLink link;

  @override
  ConsumerState<_RunningSwitch> createState() => _RunningSwitchState();
}

class _RunningSwitchState extends ConsumerState<_RunningSwitch> {
  bool _saving = false;

  Future<void> _toggle(bool on) async {
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(reviewLinkRepositoryProvider).save(
        merchantId,
        googleReviewUrl: widget.link.googleReviewUrl,
        status: on ? 'active' : 'inactive',
      );
      ref.invalidate(reviewLinkProvider);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.link.isActive;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      decoration: BoxDecoration(
        color: on ? AppColors.successBg : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: on ? AppColors.success.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(on ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: on ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? 'Review link is on' : 'Review link is paused', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  on ? 'Customers who scan can rate you.' : 'A scan shows "not active". Switch on to collect ratings again.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.smd),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Switch.adaptive(value: on, activeColor: AppColors.success, onChanged: _toggle),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageRating;
    final tiles = [
      (Icons.qr_code_scanner_rounded, '${stats.scans}', 'Scans', AppColors.businessInk),
      (Icons.star_rounded, average == null ? '–' : average.toStringAsFixed(1), 'Average rating', const Color(0xFFFFB400)),
      (Icons.rate_review_rounded, '${stats.sentToGoogle}', 'Sent to Google', AppColors.success),
      (Icons.lock_outline_rounded, '${stats.privateFeedback}', 'Private notes', AppColors.info),
    ];
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // A fixed height keeps the tiles compact on every screen width.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 76,
      ),
      children: [
        for (final t in tiles)
          Container(
            padding: const EdgeInsets.all(AppSpacing.smd),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: t.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  child: Icon(t.$1, color: t.$4, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$2, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bars for 5 down to 1 star; the ones that go to Google are green.
class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.stats, required this.threshold});

  final ReviewStats stats;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final max = [for (var s = 1; s <= 5; s++) stats.countFor(s)].fold<int>(0, (a, b) => b > a ? b : a);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${stats.ratings} rating${stats.ratings == 1 ? '' : 's'}', style: textTheme.titleSmall)),
              Text('$threshold★ and up go to Google', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          for (var stars = 5; stars >= 1; stars--)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Text('$stars', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
                  const Icon(Icons.star_rounded, size: AppIconSize.xs, color: Color(0xFFFFB400)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : stats.countFor(stars) / max,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceMuted,
                        color: stars >= threshold ? AppColors.success : AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 32,
                    child: Text('${stats.countFor(stars)}', textAlign: TextAlign.end, style: textTheme.labelMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The latest private notes, with a way to see them all.
class _FeedbackPreview extends ConsumerWidget {
  const _FeedbackPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewResponsesProvider(true));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('PRIVATE FEEDBACK', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
            ),
            TextButton(onPressed: () => context.push(BusinessRoutes.reviewLinkFeedback), child: const Text('See all')),
          ],
        ),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: e is AppException ? e.message : 'Could not load feedback.'),
          data: (items) => items.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.sentiment_satisfied_alt_rounded, size: AppIconSize.display, color: AppColors.success),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No complaints yet', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'When someone rates you 1 to 3 stars and leaves a note, it shows here, only for you.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final r in items.take(3)) ...[
                      ReviewResponseCard(response: r),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Change the Google review page the QR forwards to. The QR stays the same.
Future<void> _showEditSheet(BuildContext context, WidgetRef ref, ReviewLink link) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _EditGoogleLinkSheet(link: link),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google review link updated. Your QR code stays the same.')));
  }
}

class _EditGoogleLinkSheet extends ConsumerStatefulWidget {
  const _EditGoogleLinkSheet({required this.link});

  final ReviewLink link;

  @override
  ConsumerState<_EditGoogleLinkSheet> createState() => _EditGoogleLinkSheetState();
}

class _EditGoogleLinkSheetState extends ConsumerState<_EditGoogleLinkSheet> {
  late final _url = TextEditingController(text: widget.link.googleReviewUrl);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(reviewLinkRepositoryProvider).save(merchantId, googleReviewUrl: _url.text);
      ref.invalidate(reviewLinkProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationAppException catch (e) {
      setState(() => _error = e.fieldErrors['google_review_url']?.first ?? e.message);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.page),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google review link', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('Happy customers are sent here. Your printed QR code keeps working.', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Google review link',
              controller: _url,
              keyboardType: TextInputType.url,
              prefixIcon: Icons.link_rounded,
              errorText: _error,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Save', icon: Icons.check_rounded, isLoading: _saving, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
