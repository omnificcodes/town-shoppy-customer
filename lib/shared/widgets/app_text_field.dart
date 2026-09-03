import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled text field with an inline error message slot — the shared shape
/// every form in the app uses so 422 field errors from the backend render
/// consistently (section 63).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.prefixText,
    this.maxLength,
    this.semanticsLabel,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool enabled;
  final TextAlign textAlign;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? prefixText;
  final int? maxLength;
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
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      enabled: enabled,
      textAlign: textAlign,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      obscureText: obscureText,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        counterText: '',
        semanticCounterText: semanticsLabel,
      ),
    );
  }
}
