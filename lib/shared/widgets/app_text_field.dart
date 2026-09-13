import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';

/// Labeled text field with an inline error message slot — the shared shape
/// every form in the app uses so 422 field errors from the backend render
/// consistently (section 63). Height, radius, focus and error colors all
/// come from [AppTheme]'s `inputDecorationTheme`, never from a call site.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.errorText,
    this.helperText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.prefixText,
    this.prefixIcon,
    this.maxLength,
    this.maxLines = 1,
    this.semanticsLabel,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextAlign textAlign;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? prefixText;

  /// A leading icon, drawn in the theme's standard prefix slot.
  final IconData? prefixIcon;

  final int? maxLength;
  final int? maxLines;
  final String? semanticsLabel;

  /// Hides the entered text (a password/secret field) — `counterText`/
  /// length-limiting behavior is unaffected, so a password field can still
  /// combine this with [inputFormatters]/[maxLength] normally.
  final bool obscureText;

  /// A trailing widget (e.g. a show/hide-password toggle button).
  final Widget? suffixIcon;

  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      textAlign: textAlign,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        // Long helper copy wraps instead of vanishing into an ellipsis.
        helperMaxLines: 3,
        errorText: errorText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: AppIconSize.md),
        suffixIcon: suffixIcon,
        counterText: '',
        semanticCounterText: semanticsLabel,
      ),
    );
  }
}
