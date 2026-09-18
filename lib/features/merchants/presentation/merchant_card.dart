import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/models/merchant.dart';
import 'category_visual.dart';
import 'favorite_button.dart';
import 'merchant_logo.dart';

/// One merchant in discovery, following the Google Stitch redesign: a
/// framed logo, name, category and area, whether the shop is open now, how
/// far it is, its Town Coin discount, and direct Call / WhatsApp actions.
///
/// Every line reads `MerchantPublicResource`. The call and WhatsApp actions
/// use the merchant's own published `contact_mobile_number`, and only appear
/// when it is a dialable Indian mobile number; otherwise the card offers
/// "View shop". Stitch's star ratings, verified tick and review counts are
/// absent on purpose: nothing in the backend records them.
class MerchantCard extends StatelessWidget {
  const MerchantCard({super.key, required this.merchant, this.onTap, this.distanceKm, this.place});

  final Merchant merchant;
  final VoidCallback? onTap;

  /// Set by a nearby search, where the distance to the matching branch is known.
  final double? distanceKm;

  /// The area shown after the category; defaults to the primary branch's
  /// locality, then the association's town.
  final String? place;

  @override
  Widget build(BuildContext context) {
    final category = merchant.category;
    final visual = category == null
        ? CategoryVisual.fallback
        : CategoryVisual.forCategory(name: category.name, slug: category.slug);
    final placeLabel = place ?? merchant.branch?.locality ?? merchant.town?.name;
    final subtitle = [category?.name, placeLabel].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');
    final status = merchant.businessHours?.statusAt(DateTime.now());
    final distance = distanceKm;
    final phone = dialableIndianMobile(merchant.contactMobileNumber);
    final rate = merchant.discountRate;
    final hasDiscount = merchant.acceptsTownCoin && rate != null && rate > 0;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Semantics(
      button: onTap != null,
      label: '${merchant.name}${subtitle.isNotEmpty ? ', $subtitle' : ''}',
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: visual.color.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LogoFrame(merchant: merchant, color: visual.color),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    merchant.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: AppIconSize.sm,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ],
                            if (status != null || distance != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xxs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (status != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: status.isOpen ? AppColors.success : AppColors.textDisabled,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Flexible(
                                          child: Text(
                                            status.label,
                                            style: AppTypography.caption.copyWith(
                                              color: status.isOpen ? AppColors.success : AppColors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (distance != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: AppIconSize.xs,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: AppSpacing.xxs),
                                        Text('${_distanceLabel(distance)} away', style: AppTypography.caption),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                            if (hasDiscount) ...[const SizedBox(height: AppSpacing.sm), _TownCoinBadge(rate: rate)],
                          ],
                        ),
                      ),
                      FavoriteButton(merchantId: merchant.id, merchantName: merchant.name),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.smd, AppSpacing.smd, AppSpacing.smd),
                    child: const Divider(height: 1, color: AppColors.border),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.smd),
                    child: phone == null
                        ? _ActionButton(
                            label: 'View shop',
                            icon: Icons.storefront_rounded,
                            background: AppColors.surface,
                            foreground: AppColors.orangeDeep,
                            border: AppColors.orangeBorder,
                            semanticsLabel: 'View ${merchant.name}',
                            onTap: onTap,
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'Call now',
                                  icon: Icons.phone_rounded,
                                  background: AppColors.orangeTint,
                                  foreground: AppColors.orangeDeep,
                                  border: AppColors.orangeBorder,
                                  semanticsLabel: 'Call ${merchant.name}',
                                  onTap: () => _launch(context, Uri.parse('tel:+91$phone')),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _ActionButton(
                                  label: 'WhatsApp',
                                  icon: Icons.chat_rounded,
                                  background: AppColors.success,
                                  foreground: AppColors.onCrimson,
                                  semanticsLabel: 'WhatsApp ${merchant.name}',
                                  onTap: () => _launch(context, Uri.parse('https://wa.me/91$phone')),
                                ),
                              ),
                            ],
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

  Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open this action on your device.')));
    }
  }
}

/// The 10-digit local part of an Indian mobile number stored as
/// "9876543210", "+91 98765 43210" or "09876543210", or null for anything
/// that isn't one (so the card never dials a malformed number).
String? dialableIndianMobile(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final local = switch (digits.length) {
    10 => digits,
    11 when digits.startsWith('0') => digits.substring(1),
    12 when digits.startsWith('91') => digits.substring(2),
    _ => null,
  };
  if (local == null || !RegExp(r'^[6-9]').hasMatch(local)) return null;
  return local;
}

String _distanceLabel(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// The logo, framed in its category's colour so each card is recognisable
/// at a glance.
class _LogoFrame extends StatelessWidget {
  const _LogoFrame({required this.merchant, required this.color});

  final Merchant merchant;
  final Color color;

  static const _size = 68.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.45)],
        ),
        boxShadow: AppElevation.card,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          child: MerchantLogo(
            url: merchant.logoUrl,
            merchantName: merchant.name,
            size: AppSize.avatarLg - AppSpacing.xs,
          ),
        ),
      ),
    );
  }
}

class _TownCoinBadge extends StatelessWidget {
  const _TownCoinBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll_rounded, size: AppIconSize.xs, color: AppColors.gold),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% off with Town Coin',
                style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.semanticsLabel,
    required this.onTap,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    );

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm + AppSpacing.xs),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: AppIconSize.sm, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
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
