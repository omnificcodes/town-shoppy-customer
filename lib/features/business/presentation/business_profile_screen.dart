import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../application/business_context.dart';
import '../data/models/business_hours.dart';
import '../data/models/business_merchant.dart';
import 'business_routes.dart';
import 'business_status.dart';
import 'widgets/business_page_header.dart';

/// Read-only view of the shop's own record (`MerchantPrivateResource`).
/// Owners get an Edit action; staff see the same data with a "read only"
/// note -- `MerchantPolicy::update` is owner-only.
class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(myMerchantProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);

    return BusinessScaffold(
      title: 'Business profile',
      padded: false,
      actions: [
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () => context.push(BusinessRoutes.profileEdit),
          ),
      ],
      body: merchant.when(
        loading: () => const LoadingSkeletonList(count: 5),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load your business profile.',
          onRetry: () => ref.invalidate(myMerchantProvider),
        ),
        data: (m) => RefreshIndicator(
          onRefresh: () => ref.refresh(myMerchantProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              if (m.coverImageUrl != null && m.coverImageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, m.coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.businessTint)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppCard(
                child: Row(
                  children: [
                    MerchantLogo(url: m.logoUrl, merchantName: m.name, size: AppSize.avatarLg),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: Theme.of(context).textTheme.titleLarge),
                          if (m.tagline != null && m.tagline!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(m.tagline!, style: Theme.of(context).textTheme.bodySmall),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          StatusBadge(label: merchantStatusLabel(m.status), tone: merchantStatusTone(m.status)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOwner) ...[
                const SizedBox(height: AppSpacing.md),
                const InfoBox(
                  icon: Icons.lock_outline_rounded,
                  tone: AppTone.neutral,
                  message: 'Read only. Ask your business owner to make changes here.',
                ),
              ],
              if (m.isRejected && m.rejectionReason != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, title: 'Rejected', message: m.rejectionReason!),
              ],
              if (m.isPending) ...[
                const SizedBox(height: AppSpacing.md),
                const InfoBox(
                  icon: Icons.hourglass_top_rounded,
                  tone: AppTone.pending,
                  title: 'Pending review',
                  message: 'A Town Shoppy Super Admin reviews every application. Some actions unlock once you are approved.',
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Business identity', icon: Icons.storefront_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Business name', value: m.name),
                    DetailRow(label: 'Category', value: m.category?.name ?? '—'),
                    DetailRow(label: 'Association', value: m.association?.name ?? '—'),
                    DetailRow(label: 'Town', value: m.townName ?? '—'),
                    if (m.branch != null) DetailRow(label: 'Branch address', value: _branchAddress(m)),
                    // A paragraph, not a label/value pair -- right-aligned prose reads badly.
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(_orDash(m.description), style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Contact & compliance', icon: Icons.contact_phone_outlined),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Owner name', value: _orDash(m.ownerName)),
                    DetailRow(label: 'Contact number', value: _orDash(m.contactMobileNumber)),
                    DetailRow(label: 'Contact email', value: _orDash(m.contactEmail)),
                    DetailRow(label: 'GST number', value: _orDash(m.gstNumber)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Web presence', icon: Icons.language_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(
                      label: 'Website',
                      child: m.websiteUrl == null || m.websiteUrl!.isEmpty ? const Text('—') : _LinkText(url: m.websiteUrl!),
                    ),
                    DetailRow(
                      label: 'Social links',
                      child: m.socialLinks == null || m.socialLinks!.isEmpty
                          ? const Text('—')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [for (final e in m.socialLinks!.entries) _LinkText(url: e.value, label: e.key)],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Business hours', icon: Icons.schedule_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: m.businessHours == null || m.businessHours!.isEmpty
                    ? Text('Not set yet.', style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                        children: [
                          for (final day in merchantWeekdays)
                            DetailRow(
                              label: weekdayLabel(day),
                              value: m.businessHours!.forDay(day).closed
                                  ? 'Closed'
                                  : '${m.businessHours!.forDay(day).open} – ${m.businessHours!.forDay(day).close}',
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Rewards', icon: Icons.percent_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Discount rate', value: m.discountRate == null ? '—' : '${_trimZeros(m.discountRate!)}%'),
                    DetailRow(label: 'Accepts Town Coin', value: m.acceptsTownCoin ? 'Yes' : 'No'),
                  ],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Edit profile', icon: Icons.edit_outlined, onPressed: () => context.push(BusinessRoutes.profileEdit)),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  static String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  static String _branchAddress(BusinessMerchant m) {
    final b = m.branch!;
    final parts = [b.addressLine, b.locality, b.city].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  static String _trimZeros(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.url, this.label});

  final String url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Text(
        label ?? url,
        textAlign: TextAlign.end,
        style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.info, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
      ),
    );
  }
}
