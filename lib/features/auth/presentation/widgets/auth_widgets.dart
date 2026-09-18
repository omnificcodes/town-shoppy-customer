import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Palette local to the auth screens' illustrated look — warm creams and
/// browns that only exist on these screens. Deliberately not promoted to
/// [AppColors]: nothing else in the app paints on a cream ground.
abstract final class AuthPalette {
  static const cream = Color(0xFFFFFBF7);
  static const creamDeep = Color(0xFFFFF3E8);
  static const peach = Color(0xFFFFD8B4);
  static const peachSoft = Color(0xFFFFE6D0);
  static const iconBadge = Color(0xFFFFEBD8);
  static const brown = Color(0xFF5C2E1F);
  static const brownInk = Color(0xFF6B2F12);
  static const fieldBorder = Color(0xFFF1E1D2);
  static const script = Color(0xFFE0741A);

  /// Body copy on the cream ground (taglines, dividers, footers) — the
  /// brown palette's equivalent of [AppColors.textSecondary].
  static const mutedText = Color(0xFF6F5F57);

  /// Floating field labels and the "+91" prefix.
  static const labelText = Color(0xFF8A7A72);
  static const hintText = Color(0xFF9B8C84);

  /// The CTA gradient starts on the brand orange itself so the auth screens
  /// can never drift from [AppColors.orange].
  static const gradientStart = AppColors.orange;
  static const gradientEnd = Color(0xFFFF8E1F);
}

/// The auth screens' text field — white pill-ish card, an always-floating
/// label inside the box, a tinted circular icon badge on the left, and a
/// border that turns orange on focus. Local to auth rather than a variant
/// of the shared `AppTextField`: every other form in the app keeps the
/// standard outlined Material look.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.errorText,
    this.hintText,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.maxLength,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();

  /// The icon badge's size at the default text scale.
  static const double _badgeBase = 42;
  static const double _badgeMax = 56;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final focused = _focusNode.hasFocus;
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.error
        : focused
        ? AppColors.orange
        : AuthPalette.fieldBorder;

    // The badge grows with the user's text-scale setting (so it doesn't
    // look like a shrunken afterthought next to 2x text) but is capped so
    // it can never crowd the field's actual text out of a narrow screen.
    final badgeSize = MediaQuery.textScalerOf(context).scale(_badgeBase).clamp(_badgeBase, _badgeMax);

    // The error message sits under the box (not inside it, where Material
    // would put it) so the field keeps its height and the red border alone
    // marks the box.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: borderColor,
              width: focused || hasError ? 1.8 : 1.2,
            ),
          ),
          child: TextField(
            focusNode: _focusNode,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            obscureText: widget.obscureText,
            onSubmitted: widget.onSubmitted,
            maxLength: widget.maxLength,
            style: textTheme.bodyLarge?.copyWith(color: AuthPalette.brown),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              prefixText: widget.prefixText,
              counterText: '',
              filled: false,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: textTheme.bodyMedium?.copyWith(color: AuthPalette.labelText),
              floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: AuthPalette.labelText),
              hintStyle: textTheme.bodyLarge?.copyWith(color: AuthPalette.hintText),
              prefixStyle: textTheme.bodyLarge?.copyWith(color: AuthPalette.labelText),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.smd,
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: badgeSize + AppSpacing.smd * 2,
                minHeight: AppSpacing.touchTarget,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: const BoxDecoration(
                    color: AuthPalette.iconBadge,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: AuthPalette.brown, size: AppIconSize.md),
                ),
              ),
              suffixIcon: widget.suffixIcon,
              suffixIconColor: AuthPalette.brown,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.smd, top: AppSpacing.xs),
            child: Text(
              widget.errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// Primary CTA — full-width orange gradient pill with a trailing arrow.
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white);

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AuthPalette.gradientStart, AuthPalette.gradientEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            // The shared CTA glow. The wider hand-rolled one this replaced
            // spilled past the pill and showed up as a hard-edged tinted box
            // behind the button.
            boxShadow: AppElevation.glow(AppColors.orange),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            onTap: disabled ? null : onPressed,
            // A minimum, not a fixed, height -- a fixed box clipped this
            // button's own label at a large system text-scale setting.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.controlLg),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.md,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: AppIconSize.lg,
                          height: AppIconSize.lg,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(label, style: labelStyle),
                            const SizedBox(width: AppSpacing.smd),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: AppIconSize.lg,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary CTA — white pill with an orange outline (Login's "Create an
/// account").
class AuthOutlinedPillButton extends StatelessWidget {
  const AuthOutlinedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.orange,
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        side: const BorderSide(color: AppColors.orange, width: 1.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
        // minimumSize, not a fixed-height box, so it can grow at a large
        // system text-scale setting instead of clipping its own label.
        minimumSize: const Size(double.infinity, AppSize.controlLg),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      child: Text(label),
    );
  }
}

/// Secondary CTA — tinted pill mixing plain and orange text (Register's
/// "Already have an account? Sign in").
class AuthTintedPillButton extends StatelessWidget {
  const AuthTintedPillButton({
    super.key,
    required this.leading,
    required this.trailing,
    required this.onPressed,
  });

  final String leading;
  final String trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AuthPalette.iconBadge,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.controlLg),
          child: Center(
            // Wrap, not Row -- at a large text-scale setting this no longer
            // fits one line; Wrap drops the trailing segment to a second
            // line instead of throwing a RenderFlex overflow.
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.md,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(leading, style: textTheme.titleMedium?.copyWith(color: AuthPalette.brown)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(trailing, style: textTheme.titleMedium?.copyWith(color: AppColors.orange)),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.orange,
                    size: AppIconSize.md,
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

/// "New to Town Shoppy?" / "OR" — a centered label between two hairlines.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthPalette.fieldBorder)),
        // Flexible + a fixed flex share so a large text-scale setting can
        // never push this label past the row's width (a real overflow the
        // Phase 10 accessibility sweep caught in an earlier version).
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AuthPalette.fieldBorder)),
      ],
    );
  }
}

/// Handwritten script (the bundled Caveat font) for the decorative
/// taglines. Text scale is pinned: this is flourish sitting inside
/// fixed-size art, not readable content — the real headings carry the
/// meaning and scale normally.
class AuthScriptText extends StatelessWidget {
  const AuthScriptText(
    this.text, {
    super.key,
    this.size = 22,
    this.color = AuthPalette.script,
    this.align = TextAlign.right,
    this.angle = 0,
    this.lineHeight = 1.05,
  });

  final String text;
  final double size;
  final Color color;
  final TextAlign align;
  final double angle;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: angle,
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontFamily: 'Caveat',
              fontVariations: const [FontVariation('wght', 700)],
              fontWeight: FontWeight.w700,
              fontSize: size,
              height: lineHeight,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + "SHOP · SAVE · WIN" + the little orange underline, shared by all
/// four auth screens.
class AuthBrandBlock extends StatelessWidget {
  const AuthBrandBlock({super.key, this.logoHeight = 80});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The logo PNG has an opaque white background; multiplying the
        // cream ground into it makes that box vanish on these cream screens
        // (white × cream = cream) while leaving the orange lettering intact.
        Image.asset(
          'assets/images/townshoppy_logo.png',
          height: logoHeight,
          semanticLabel: 'Town Shoppy',
          color: AuthPalette.cream,
          colorBlendMode: BlendMode.multiply,
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            // IntrinsicWidth + centre alignment puts the underline under
            // the middle word ("SAVE") whatever the text measures, instead
            // of a hand-tuned left inset.
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SHOP  ·  SAVE  ·  WIN',
                    style: AppTypography.overline.copyWith(color: AuthPalette.brown, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: AppSpacing.xl,
                    height: AppSpacing.xxs,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(AppSpacing.xxs),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The back-button row at the top of Register, Forgot and Reset (Login has
/// none). One widget so the button's size, colour and placement are the
/// same on all three: a 48dp target whose arrow glyph — not its hit box —
/// lines up with the [AppSpacing.page] margin the content below uses.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  static const double _glyphInset = (AppSpacing.touchTarget - AppIconSize.lg) / 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.page - _glyphInset, top: AppSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AuthPalette.brown,
          iconSize: AppIconSize.lg,
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
          ),
          onPressed: onBack,
        ),
      ),
    );
  }
}
