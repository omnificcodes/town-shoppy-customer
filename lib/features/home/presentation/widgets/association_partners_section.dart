import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../merchants/application/associations_provider.dart';
import '../../../merchants/data/models/association_ref.dart';

/// The merchant associations Town Shoppy works with, from the public
/// `GET /associations` list.
///
/// Stitch scrolls these as an auto-playing marquee; this is a normal
/// swipeable row instead, because content that moves on its own is hard to
/// read and can't be paused by everyone. Stitch's "Verified Network" chip is
/// also left out -- it's a claim the data doesn't make. The whole section
/// hides while loading, on error, or when there are none, since it's a
/// credibility strip rather than something Home depends on.
///
/// Each tile shows the association's full name (two lines at most) and
/// opens the list of every shop in it.
class AssociationPartnersSection extends ConsumerWidget {
  const AssociationPartnersSection({super.key});

  static const _tileWidth = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final associations = ref.watch(associationsProvider).value;
    if (associations == null || associations.isEmpty) return const SizedBox.shrink();

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final tileHeight = AppSpacing.sm * 2 + AppSize.avatarMd + AppSpacing.xs + (18 * 2 + 16) * scale + AppSpacing.xs;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.section),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          gradient: AppGradients.warmWash,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.orangeBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: const Text('Association Partners', style: AppTypography.sectionTitle)),
            const SizedBox(height: AppSpacing.xxs),
            Text('Official local merchant federations', style: AppTypography.caption.copyWith(color: AppColors.goldDark)),
            const SizedBox(height: AppSpacing.smd),
            SizedBox(
              height: tileHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: associations.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => _PartnerTile(association: associations[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({required this.association});

  final AssociationRef association;

  @override
  Widget build(BuildContext context) {
    final code = association.shortCode ?? _initials(association.name);
    final town = association.town?.name;
    final logoUrl = association.logoUrl;

    final radius = BorderRadius.circular(AppSpacing.radiusControl);

    return Semantics(
      button: true,
      label: town == null ? '${association.name}, view shops' : '${association.name}, $town, view shops',
      excludeSemantics: true,
      child: Container(
        width: AssociationPartnersSection._tileWidth,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.goldLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/associations/${association.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  Container(
                    width: AppSize.avatarMd,
                    height: AppSize.avatarMd,
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: logoUrl == null
                        ? _CodeMark(code: code)
                        : Image.network(
                            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _CodeMark(code: code),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // The full name -- the short code / initials only fill the logo
                  // mark, where a single-word name used to leave just one letter.
                  Text(
                    association.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (town != null)
                    Text(
                      town,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }
}

class _CodeMark extends StatelessWidget {
  const _CodeMark({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Text(
      code.length > 3 ? code.substring(0, 3) : code,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w700),
    );
  }
}
